using Azure.Identity;
using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();
builder.Services.AddHealthChecks();

// Configure Data Protection to use shared Azure Blob Storage
// This ensures both slots can decrypt each other's session cookies
var blobUri = builder.Configuration["DataProtection__BlobUri"];
if (!string.IsNullOrEmpty(blobUri))
{
    builder.Services.AddDataProtection()
        .SetApplicationName("SlotDemo")
        .PersistKeysToAzureBlobStorage(new Uri(blobUri), new DefaultAzureCredential());
}
else
{
    builder.Services.AddDataProtection()
        .SetApplicationName("SlotDemo");
}

builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
});

builder.Services.AddDistributedMemoryCache();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseSession();
app.MapHealthChecks("/healthz");
app.MapRazorPages();

app.Run();
