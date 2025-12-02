using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Web.Http;
using System.Web.Http.ModelBinding;
using SampleApi.Models;
using SampleApi.Services;

namespace SampleApi.Controllers
{
    /// <summary>
    /// Controller for Customer CRUD operations
    /// </summary>
    [RoutePrefix("api/customers")]
    public class CustomersController : ApiController
    {
        private readonly CustomerService _customerService;

        /// <summary>
        /// Constructor - initializes the customer service
        /// </summary>
        public CustomersController()
        {
            _customerService = new CustomerService();
        }

        /// <summary>
        /// Gets all customers or paginated customers
        /// GET: api/customers
        /// GET: api/customers?page=1&pageSize=10
        /// </summary>
        /// <param name="page">Page number (optional, defaults to 1)</param>
        /// <param name="pageSize">Items per page (optional, defaults to 0 for all)</param>
        /// <returns>List of customers</returns>
        [HttpGet]
        [Route("")]
        public async Task<IHttpActionResult> GetCustomers(int page = 0, int pageSize = 0)
        {
            try
            {
                // If pagination parameters are provided, use pagination
                if (page > 0 && pageSize > 0)
                {
                    var (customers, totalCount) = await _customerService.GetCustomersPagedAsync(page, pageSize);
                    
                    var metadata = new
                    {
                        currentPage = page,
                        pageSize = pageSize,
                        totalCount = totalCount,
                        totalPages = (int)Math.Ceiling((double)totalCount / pageSize),
                        hasNextPage = page * pageSize < totalCount,
                        hasPreviousPage = page > 1
                    };

                    var response = ApiResponse<List<Customer>>.SuccessResponse(
                        customers,
                        metadata,
                        $"Retrieved {customers.Count} customers (page {page} of {metadata.totalPages})"
                    );
                    
                    return Ok(response);
                }
                else
                {
                    // Return all customers
                    var allCustomers = await _customerService.GetAllCustomersAsync();
                    
                    var response = ApiResponse<List<Customer>>.SuccessResponse(
                        allCustomers,
                        $"Retrieved {allCustomers.Count} customers"
                    );
                    
                    return Ok(response);
                }
            }
            catch (Exception ex)
            {
                var errorResponse = ApiResponse<List<Customer>>.ErrorResponse(
                    "Failed to retrieve customers",
                    ex.Message
                );
                
                return InternalServerError();
            }
        }

        /// <summary>
        /// Gets a specific customer by ID
        /// GET: api/customers/5
        /// </summary>
        /// <param name="id">Customer ID</param>
        /// <returns>Customer details</returns>
        [HttpGet]
        [Route("{id:int}")]
        public async Task<IHttpActionResult> GetCustomer(int id)
        {
            try
            {
                if (id <= 0)
                {
                    var validationResponse = ApiResponse<Customer>.ErrorResponse(
                        "Invalid customer ID",
                        "Customer ID must be a positive integer"
                    );
                    return BadRequest(ModelState);
                }

                var customer = await _customerService.GetCustomerByIdAsync(id);
                
                if (customer == null)
                {
                    var notFoundResponse = ApiResponse<Customer>.NotFoundResponse(
                        $"Customer with ID {id} not found"
                    );
                    return NotFound();
                }

                var response = ApiResponse<Customer>.SuccessResponse(
                    customer,
                    $"Customer {customer.FullName} retrieved successfully"
                );
                
                return Ok(response);
            }
            catch (Exception ex)
            {
                var errorResponse = ApiResponse<Customer>.ErrorResponse(
                    "Failed to retrieve customer",
                    ex.Message
                );
                
                return InternalServerError();
            }
        }

        /// <summary>
        /// Creates a new customer
        /// POST: api/customers
        /// </summary>
        /// <param name="customer">Customer data</param>
        /// <returns>Created customer</returns>
        [HttpPost]
        [Route("")]
        public async Task<IHttpActionResult> CreateCustomer([FromBody] Customer customer)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    var validationErrors = ModelState.Values
                        .SelectMany(v => v.Errors)
                        .Select(e => e.ErrorMessage)
                        .ToList();

                    var validationResponse = ApiResponse<Customer>.ValidationErrorResponse(validationErrors);
                    return BadRequest(ModelState);
                }

                if (customer == null)
                {
                    var nullResponse = ApiResponse<Customer>.ErrorResponse(
                        "Invalid request",
                        "Customer data is required"
                    );
                    return BadRequest(ModelState);
                }

                var createdCustomer = await _customerService.CreateCustomerAsync(customer);
                
                var response = ApiResponse<Customer>.SuccessResponse(
                    createdCustomer,
                    $"Customer {createdCustomer.FullName} created successfully"
                );
                
                return Created($"api/customers/{createdCustomer.Id}", response);
            }
            catch (ArgumentException ex)
            {
                var validationResponse = ApiResponse<Customer>.ErrorResponse(
                    "Validation failed",
                    ex.Message
                );
                return BadRequest(ModelState);
            }
            catch (InvalidOperationException ex)
            {
                var conflictResponse = ApiResponse<Customer>.ErrorResponse(
                    "Operation failed",
                    ex.Message
                );
                return Conflict();
            }
            catch (Exception ex)
            {
                var errorResponse = ApiResponse<Customer>.ErrorResponse(
                    "Failed to create customer",
                    ex.Message
                );
                
                return InternalServerError();
            }
        }

        /// <summary>
        /// Updates an existing customer
        /// PUT: api/customers/5
        /// </summary>
        /// <param name="id">Customer ID</param>
        /// <param name="customer">Updated customer data</param>
        /// <returns>Updated customer</returns>
        [HttpPut]
        [Route("{id:int}")]
        public async Task<IHttpActionResult> UpdateCustomer(int id, [FromBody] Customer customer)
        {
            try
            {
                if (id <= 0)
                {
                    var idValidationResponse = ApiResponse<Customer>.ErrorResponse(
                        "Invalid customer ID",
                        "Customer ID must be a positive integer"
                    );
                    return BadRequest(ModelState);
                }

                if (!ModelState.IsValid)
                {
                    var validationErrors = ModelState.Values
                        .SelectMany(v => v.Errors)
                        .Select(e => e.ErrorMessage)
                        .ToList();

                    var validationResponse = ApiResponse<Customer>.ValidationErrorResponse(validationErrors);
                    return BadRequest(ModelState);
                }

                if (customer == null)
                {
                    var nullResponse = ApiResponse<Customer>.ErrorResponse(
                        "Invalid request",
                        "Customer data is required"
                    );
                    return BadRequest(ModelState);
                }

                var updatedCustomer = await _customerService.UpdateCustomerAsync(id, customer);
                
                if (updatedCustomer == null)
                {
                    var notFoundResponse = ApiResponse<Customer>.NotFoundResponse(
                        $"Customer with ID {id} not found"
                    );
                    return NotFound();
                }

                var response = ApiResponse<Customer>.SuccessResponse(
                    updatedCustomer,
                    $"Customer {updatedCustomer.FullName} updated successfully"
                );
                
                return Ok(response);
            }
            catch (ArgumentException ex)
            {
                var validationResponse = ApiResponse<Customer>.ErrorResponse(
                    "Validation failed",
                    ex.Message
                );
                return BadRequest(ModelState);
            }
            catch (InvalidOperationException ex)
            {
                var conflictResponse = ApiResponse<Customer>.ErrorResponse(
                    "Operation failed",
                    ex.Message
                );
                return Conflict();
            }
            catch (Exception ex)
            {
                var errorResponse = ApiResponse<Customer>.ErrorResponse(
                    "Failed to update customer",
                    ex.Message
                );
                
                return InternalServerError();
            }
        }

        /// <summary>
        /// Deletes a customer
        /// DELETE: api/customers/5
        /// </summary>
        /// <param name="id">Customer ID</param>
        /// <returns>Deletion confirmation</returns>
        [HttpDelete]
        [Route("{id:int}")]
        public async Task<IHttpActionResult> DeleteCustomer(int id)
        {
            try
            {
                if (id <= 0)
                {
                    var validationResponse = ApiResponse.ErrorResponse(
                        "Invalid customer ID",
                        "Customer ID must be a positive integer"
                    );
                    return BadRequest(ModelState);
                }

                var deleted = await _customerService.DeleteCustomerAsync(id);
                
                if (!deleted)
                {
                    var notFoundResponse = ApiResponse.NotFoundResponse(
                        $"Customer with ID {id} not found"
                    );
                    return NotFound();
                }

                var response = ApiResponse.SuccessResponse(
                    $"Customer with ID {id} deleted successfully"
                );
                
                return Ok(response);
            }
            catch (Exception ex)
            {
                var errorResponse = ApiResponse.ErrorResponse(
                    "Failed to delete customer",
                    ex.Message
                );
                
                return InternalServerError();
            }
        }

        /// <summary>
        /// Searches customers by email
        /// GET: api/customers/search/email/{email}
        /// </summary>
        /// <param name="email">Email address to search for</param>
        /// <returns>Customer if found</returns>
        [HttpGet]
        [Route("search/email/{email}")]
        public async Task<IHttpActionResult> SearchByEmail(string email)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(email))
                {
                    var validationResponse = ApiResponse<Customer>.ErrorResponse(
                        "Invalid email",
                        "Email address is required"
                    );
                    return BadRequest(ModelState);
                }

                var customer = await _customerService.GetCustomerByEmailAsync(email);
                
                if (customer == null)
                {
                    var notFoundResponse = ApiResponse<Customer>.NotFoundResponse(
                        $"No customer found with email '{email}'"
                    );
                    return NotFound();
                }

                var response = ApiResponse<Customer>.SuccessResponse(
                    customer,
                    $"Customer found with email '{email}'"
                );
                
                return Ok(response);
            }
            catch (Exception ex)
            {
                var errorResponse = ApiResponse<Customer>.ErrorResponse(
                    "Failed to search customer by email",
                    ex.Message
                );
                
                return InternalServerError();
            }
        }

        /// <summary>
        /// Gets customer statistics
        /// GET: api/customers/stats
        /// </summary>
        /// <returns>Customer statistics</returns>
        [HttpGet]
        [Route("stats")]
        public async Task<IHttpActionResult> GetCustomerStats()
        {
            try
            {
                var allCustomers = await _customerService.GetAllCustomersAsync();
                
                var stats = new
                {
                    totalCustomers = allCustomers.Count,
                    customersWithPhone = allCustomers.Count(c => !string.IsNullOrWhiteSpace(c.Phone)),
                    customersWithoutPhone = allCustomers.Count(c => string.IsNullOrWhiteSpace(c.Phone)),
                    newestCustomer = allCustomers.OrderByDescending(c => c.DateCreated).FirstOrDefault(),
                    oldestCustomer = allCustomers.OrderBy(c => c.DateCreated).FirstOrDefault(),
                    recentlyModified = allCustomers.OrderByDescending(c => c.DateModified).Take(5).ToList()
                };

                var response = ApiResponse<object>.SuccessResponse(
                    stats,
                    "Customer statistics retrieved successfully"
                );
                
                return Ok(response);
            }
            catch (Exception ex)
            {
                var errorResponse = ApiResponse<object>.ErrorResponse(
                    "Failed to retrieve customer statistics",
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