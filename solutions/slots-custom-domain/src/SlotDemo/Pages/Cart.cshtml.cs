using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace SlotDemo.Pages;

public class CartModel : PageModel
{
    public List<string> CartItems { get; set; } = new();

    private const string CartKey = "CartItems";

    public void OnGet()
    {
        CartItems = GetCart();
    }

    public IActionResult OnPostAdd(string item)
    {
        if (!string.IsNullOrWhiteSpace(item))
        {
            var cart = GetCart();
            cart.Add(item.Trim());
            SaveCart(cart);
        }
        return RedirectToPage();
    }

    public IActionResult OnPostRemove(string item)
    {
        var cart = GetCart();
        cart.Remove(item);
        SaveCart(cart);
        return RedirectToPage();
    }

    public IActionResult OnPostClear()
    {
        SaveCart(new List<string>());
        return RedirectToPage();
    }

    private List<string> GetCart()
    {
        var json = HttpContext.Session.GetString(CartKey);
        return string.IsNullOrEmpty(json)
            ? new List<string>()
            : JsonSerializer.Deserialize<List<string>>(json) ?? new List<string>();
    }

    private void SaveCart(List<string> cart)
    {
        HttpContext.Session.SetString(CartKey, JsonSerializer.Serialize(cart));
    }
}
