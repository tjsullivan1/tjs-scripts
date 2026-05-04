using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace SlotDemo.Pages;

public class IndexModel : PageModel
{
    public int VisitCount { get; set; }

    public void OnGet()
    {
        VisitCount = HttpContext.Session.GetInt32("VisitCount") ?? 0;
        VisitCount++;
        HttpContext.Session.SetInt32("VisitCount", VisitCount);
    }

    public IActionResult OnPostReset()
    {
        HttpContext.Session.SetInt32("VisitCount", 0);
        return RedirectToPage();
    }
}
