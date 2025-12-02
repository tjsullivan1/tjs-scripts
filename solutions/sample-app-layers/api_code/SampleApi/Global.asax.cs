using System;
using System.Web;
using System.Web.Http;
using System.Web.Mvc;

namespace SampleApi
{
    public class WebApiApplication : HttpApplication
    {
        protected void Application_Start()
        {
            // Initialize Web API configuration
            GlobalConfiguration.Configure(WebApiConfig.Register);
            
            // Initialize MVC filters
            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
        }
        
        protected void Application_Error()
        {
            var exception = Server.GetLastError();
            
            // Log the exception (you can implement logging as needed)
            System.Diagnostics.Debug.WriteLine($"Unhandled exception: {exception?.Message}");
            
            // Clear the error
            Server.ClearError();
            
            // Set a generic error response
            Response.StatusCode = 500;
            Response.ContentType = "application/json";
            Response.Write("{\"success\":false,\"message\":\"An internal server error occurred.\",\"data\":null,\"errors\":[]}");
        }
    }
}