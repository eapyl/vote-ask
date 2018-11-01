using Microsoft.AspNetCore.Mvc;

namespace voute_ask
{
    public class HomeController : Controller
    {
        [HttpGet]
        public IActionResult Spa()
        {
            return File("~/index.html", "text/html");
        }
    }
}