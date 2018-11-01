using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace voute_ask
{
    public class VotingHub : Hub
    {
        private static ConcurrentDictionary<string, string> _connectionIdToVotingId = new ConcurrentDictionary<string, string>();
        private IMemoryCache _cache;
        private readonly ILogger<VotingHub> _logger;

        public VotingHub(IMemoryCache memoryCache, ILogger<VotingHub> logger)
        {
            _cache = memoryCache;
            _logger = logger;
        }

        public class Variant
        {
            public int Id { get; set; }
            public string Text { get; set; }
        }

        public class UserAnswer
        {
            public int VariantId { get; set; }
            public string User { get; set; }
        }

        public class Voting
        {
            public string Id { get; set; }
            public string Question { get; set; }
            public List<Variant> Variants { get; set; }
            [JsonIgnore]
            public ConcurrentDictionary<string, UserAnswer> _internalAnswers { get; set; }
            public List<UserAnswer> Answers
            {
                get
                {
                    return _internalAnswers.Values.ToList();
                }
            }
            public bool IsClosed { get; set; }
        }

        private static ConcurrentDictionary<string, string> _votings = 
            new ConcurrentDictionary<string, string>();

        public async Task SendMessage(string message)
        {
            dynamic json = JValue.Parse(message);
            string action = json.action;
            switch (action)
            {
                case nameof(CheckVoting):
                    await CheckVoting(json);
                    break;
                case nameof(SubmitVoting):
                    await SubmitVoting(json);
                    break;
                case nameof(GetExistingVoting):
                    await GetExistingVoting(json);
                    break;
                case nameof(SubmitVoteVariant):
                    await SubmitVoteVariant(json);
                    break;
                case nameof(CloseVoting):
                    await CloseVoting(json);
                    break;
            }
        }

        // Create new voting
        private async Task SubmitVoting(dynamic json)
        {
            var voting = new Voting
                { Variants = new List<Variant>()
                , Id = NewId()
                , _internalAnswers = new ConcurrentDictionary<string, UserAnswer>()
                };
            voting.Question = json.question;
            foreach (dynamic  variant in json.variants)
            {
                int id = variant.id;
                string text = variant.text;
                voting.Variants.Add(new Variant { Id = id, Text = text });
            }

            if (_cache.TryGetValue(voting.Id, out _ ))
            {
                throw new ApplicationException("Generated duplicated id for voting.");
            }

            var options = new MemoryCacheEntryOptions()
                .RegisterPostEvictionCallback(callback: EvictionCallback);
            voting = _cache.Set(voting.Id, voting, options);

            if (!_connectionIdToVotingId.TryAdd(Context.ConnectionId, voting.Id))
            {
                if (_connectionIdToVotingId.TryRemove(Context.ConnectionId, out string oldVotingId))
                {
                    await InternalCloseVoting(oldVotingId);
                    if (!_connectionIdToVotingId.TryAdd(Context.ConnectionId, voting.Id))
                    {
                        throw new ApplicationException("Can't add voting id to dictionary.");
                    }
                }
            }

            await Groups.AddToGroupAsync(Context.ConnectionId, voting.Id);

            await Clients.Caller.SendAsync("ReceiveMessage", JsonConvert.SerializeObject(new { votingId = voting.Id }));
        }

        // Clean up dictionary of we are removing voting from memory
        private void EvictionCallback(object key, object value, EvictionReason reason, object state)
        {
            foreach(var item in _connectionIdToVotingId.Where(kvp => kvp.Value == key.ToString()).ToList())
            {
                _connectionIdToVotingId.Remove(item.Key, out _);
            }
        }

        /// Check if voting exists
        private async Task CheckVoting(dynamic json)
        {
            string votingId = json.votingId;
            if (_cache.TryGetValue(votingId, out _ ))
            {
                await Clients.Caller.SendAsync("ReceiveMessage", JsonConvert.SerializeObject(new { votingId = votingId }));
                return;
            }
            await Clients.Caller.SendAsync("ReceiveMessage", JsonConvert.SerializeObject(new { }));
        }

        private string NewId() => Guid.NewGuid().ToString("N");

        /// Get existing voting by votingId
        private async Task GetExistingVoting(dynamic json)
        {
            string votingId = json.votingId;
            if (_cache.TryGetValue(votingId, out Voting voting))
            {
                await Groups.AddToGroupAsync(Context.ConnectionId, voting.Id);
                await Clients.Caller.SendAsync("ReceiveMessage", JsonConvert.SerializeObject(voting));
                return;
            }
            await Clients.Caller.SendAsync("ReceiveMessage", JsonConvert.SerializeObject(new { }));
        }

        private async Task SubmitVoteVariant(dynamic json)
        {
            string votingId = json.votingId;
            int variantId = json.variantId;
            string user = json.user;
            if (_cache.TryGetValue(votingId, out Voting voting))
            {
                _logger.LogInformation(JsonConvert.SerializeObject(voting));

                voting._internalAnswers.TryRemove(Context.ConnectionId, out _);

                voting._internalAnswers.TryAdd(Context.ConnectionId, new UserAnswer {
                    User = user,
                    VariantId = variantId
                });

                await Clients.Group(votingId).SendAsync("ReceiveMessage", JsonConvert.SerializeObject(voting));
                return;
            }
        }

        private async Task CloseVoting(dynamic json)
        {
            string votingId = json.votingId;
            if (await InternalCloseVoting(votingId))
                return;
        }

        /// Closing voting if creator disconnected and notifying all voters
        public override async Task OnDisconnectedAsync(Exception exception)
        {
            if (_connectionIdToVotingId.TryGetValue(Context.ConnectionId, out string votingId))
            {
                await InternalCloseVoting(votingId);
            }
        }

        private async Task<bool> InternalCloseVoting(string votingId)
        {
            if (_cache.TryGetValue(votingId, out Voting voting))
            {
                voting.IsClosed = true;
                await Clients.Group(votingId).SendAsync("ReceiveMessage", JsonConvert.SerializeObject(voting));
                return true;
            }
            return false;
        }
    }
}