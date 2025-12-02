using System;
using System.Threading.Tasks;
using System.Web.Http;
using SampleApi.Models;
using SampleApi.Services;

namespace SampleApi.Controllers
{
    /// <summary>
    /// Controller for database seeding operations
    /// </summary>
    [RoutePrefix("api/seed")]
    public class SeedController : ApiController
    {
        private readonly CustomerService _customerService;

        /// <summary>
        /// Constructor - initializes the customer service
        /// </summary>
        public SeedController()
        {
            _customerService = new CustomerService();
        }

        /// <summary>
        /// Seeds the database with sample customer data
        /// GET: api/seed
        /// </summary>
        /// <returns>API response indicating seeding result</returns>
        [HttpGet]
        [Route("")]
        public async Task<IHttpActionResult> SeedDatabase()
        {
            try
            {
                var customersCreated = await _customerService.SeedDatabaseAsync();
                
                if (customersCreated == 0)
                {
                    var response = ApiResponse<object>.SuccessResponse(
                        null,
                        "Database already contains data. No seeding performed."
                    );
                    return Ok(response);
                }

                var successResponse = ApiResponse<object>.SuccessResponse(
                    new { customersCreated = customersCreated },
                    $"Successfully seeded database with {customersCreated} sample customers."
                );
                
                return Ok(successResponse);
            }
            catch (Exception ex)
            {
                var errorResponse = ApiResponse<object>.ErrorResponse(
                    "Failed to seed database",
                    ex.Message
                );
                
                return InternalServerError();
            }
        }

        /// <summary>
        /// Forces database seeding by clearing existing data and adding sample data
        /// GET: api/seed/force
        /// </summary>
        /// <returns>API response indicating seeding result</returns>
        [HttpGet]
        [Route("force")]
        public async Task<IHttpActionResult> ForceSeedDatabase()
        {
            try
            {
                var customersCreated = await _customerService.ForceSeedDatabaseAsync();
                
                var response = ApiResponse<object>.SuccessResponse(
                    new { customersCreated = customersCreated },
                    $"Successfully cleared and re-seeded database with {customersCreated} sample customers."
                );
                
                return Ok(response);
            }
            catch (Exception ex)
            {
                var errorResponse = ApiResponse<object>.ErrorResponse(
                    "Failed to force seed database",
                    ex.Message
                );
                
                return InternalServerError();
            }
        }

        /// <summary>
        /// Gets database status information
        /// GET: api/seed/status
        /// </summary>
        /// <returns>Current database statistics</returns>
        [HttpGet]
        [Route("status")]
        public async Task<IHttpActionResult> GetDatabaseStatus()
        {
            try
            {
                var allCustomers = await _customerService.GetAllCustomersAsync();
                
                var statusInfo = new
                {
                    totalCustomers = allCustomers.Count,
                    hasData = allCustomers.Count > 0,
                    lastModified = allCustomers.Count > 0 
                        ? allCustomers.Max(c => c.DateModified)
                        : (DateTime?)null
                };

                var response = ApiResponse<object>.SuccessResponse(
                    statusInfo,
                    "Database status retrieved successfully"
                );
                
                return Ok(response);
            }
            catch (Exception ex)
            {
                var errorResponse = ApiResponse<object>.ErrorResponse(
                    "Failed to retrieve database status",
                    ex.Message
                );
                
                return InternalServerError();
            }
        }

        /// <summary>
        /// Dispose resources when controller is disposed
        /// </summary>
        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                _customerService?.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}