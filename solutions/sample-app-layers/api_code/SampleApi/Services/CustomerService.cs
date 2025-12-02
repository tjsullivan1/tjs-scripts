using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Threading.Tasks;
using SampleApi.Models;

namespace SampleApi.Services
{
    /// <summary>
    /// Service class for handling Customer business logic and data operations
    /// </summary>
    public class CustomerService : IDisposable
    {
        private readonly DatabaseContext _context;
        private bool _disposed = false;

        /// <summary>
        /// Constructor - initializes the database context
        /// </summary>
        public CustomerService()
        {
            _context = new DatabaseContext();
        }

        /// <summary>
        /// Constructor with dependency injection support
        /// </summary>
        /// <param name="context">Database context instance</param>
        public CustomerService(DatabaseContext context)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
        }

        #region Customer CRUD Operations

        /// <summary>
        /// Retrieves all customers from the database
        /// </summary>
        /// <returns>List of all customers</returns>
        public async Task<List<Customer>> GetAllCustomersAsync()
        {
            try
            {
                return await _context.Customers
                    .OrderBy(c => c.LastName)
                    .ThenBy(c => c.FirstName)
                    .ToListAsync();
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Error retrieving customers: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Retrieves customers with pagination support
        /// </summary>
        /// <param name="pageNumber">Page number (1-based)</param>
        /// <param name="pageSize">Number of items per page</param>
        /// <returns>Paginated list of customers</returns>
        public async Task<(List<Customer> customers, int totalCount)> GetCustomersPagedAsync(int pageNumber = 1, int pageSize = 10)
        {
            try
            {
                if (pageNumber < 1) pageNumber = 1;
                if (pageSize < 1) pageSize = 10;
                if (pageSize > 100) pageSize = 100; // Limit max page size

                var query = _context.Customers
                    .OrderBy(c => c.LastName)
                    .ThenBy(c => c.FirstName);

                var totalCount = await query.CountAsync();
                
                var customers = await query
                    .Skip((pageNumber - 1) * pageSize)
                    .Take(pageSize)
                    .ToListAsync();

                return (customers, totalCount);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Error retrieving paginated customers: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Retrieves a specific customer by ID
        /// </summary>
        /// <param name="id">Customer ID</param>
        /// <returns>Customer if found, null otherwise</returns>
        public async Task<Customer> GetCustomerByIdAsync(int id)
        {
            try
            {
                return await _context.Customers.FindAsync(id);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Error retrieving customer with ID {id}: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Retrieves a customer by email address
        /// </summary>
        /// <param name="email">Email address</param>
        /// <returns>Customer if found, null otherwise</returns>
        public async Task<Customer> GetCustomerByEmailAsync(string email)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(email))
                    return null;

                return await _context.Customers
                    .FirstOrDefaultAsync(c => c.Email.ToLower() == email.ToLower());
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Error retrieving customer with email {email}: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Creates a new customer
        /// </summary>
        /// <param name="customer">Customer to create</param>
        /// <returns>Created customer with assigned ID</returns>
        public async Task<Customer> CreateCustomerAsync(Customer customer)
        {
            try
            {
                if (customer == null)
                    throw new ArgumentNullException(nameof(customer));

                // Validate customer data
                var validationErrors = ValidateCustomer(customer);
                if (validationErrors.Any())
                    throw new ArgumentException($"Validation failed: {string.Join(", ", validationErrors)}");

                // Check for duplicate email
                var existingCustomer = await GetCustomerByEmailAsync(customer.Email);
                if (existingCustomer != null)
                    throw new InvalidOperationException($"A customer with email '{customer.Email}' already exists.");

                // Set timestamps
                customer.DateCreated = DateTime.UtcNow;
                customer.DateModified = DateTime.UtcNow;

                _context.Customers.Add(customer);
                await _context.SaveChangesAsync();

                return customer;
            }
            catch (Exception ex) when (!(ex is ArgumentNullException || ex is ArgumentException || ex is InvalidOperationException))
            {
                throw new InvalidOperationException($"Error creating customer: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Updates an existing customer
        /// </summary>
        /// <param name="id">Customer ID to update</param>
        /// <param name="updatedCustomer">Updated customer data</param>
        /// <returns>Updated customer if successful, null if not found</returns>
        public async Task<Customer> UpdateCustomerAsync(int id, Customer updatedCustomer)
        {
            try
            {
                if (updatedCustomer == null)
                    throw new ArgumentNullException(nameof(updatedCustomer));

                var existingCustomer = await GetCustomerByIdAsync(id);
                if (existingCustomer == null)
                    return null;

                // Validate updated customer data
                var validationErrors = ValidateCustomer(updatedCustomer);
                if (validationErrors.Any())
                    throw new ArgumentException($"Validation failed: {string.Join(", ", validationErrors)}");

                // Check for duplicate email (excluding current customer)
                var customerWithSameEmail = await GetCustomerByEmailAsync(updatedCustomer.Email);
                if (customerWithSameEmail != null && customerWithSameEmail.Id != id)
                    throw new InvalidOperationException($"A customer with email '{updatedCustomer.Email}' already exists.");

                // Update properties
                existingCustomer.FirstName = updatedCustomer.FirstName;
                existingCustomer.LastName = updatedCustomer.LastName;
                existingCustomer.Email = updatedCustomer.Email;
                existingCustomer.Phone = updatedCustomer.Phone;
                existingCustomer.UpdateModifiedDate();

                await _context.SaveChangesAsync();
                return existingCustomer;
            }
            catch (Exception ex) when (!(ex is ArgumentNullException || ex is ArgumentException || ex is InvalidOperationException))
            {
                throw new InvalidOperationException($"Error updating customer with ID {id}: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Deletes a customer by ID
        /// </summary>
        /// <param name="id">Customer ID to delete</param>
        /// <returns>True if deleted, false if not found</returns>
        public async Task<bool> DeleteCustomerAsync(int id)
        {
            try
            {
                var customer = await GetCustomerByIdAsync(id);
                if (customer == null)
                    return false;

                _context.Customers.Remove(customer);
                await _context.SaveChangesAsync();
                return true;
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Error deleting customer with ID {id}: {ex.Message}", ex);
            }
        }

        #endregion

        #region Database Seeding

        /// <summary>
        /// Seeds the database with sample customer data
        /// </summary>
        /// <returns>Number of customers created</returns>
        public async Task<int> SeedDatabaseAsync()
        {
            try
            {
                // Check if data already exists
                var existingCount = await _context.Customers.CountAsync();
                if (existingCount > 0)
                {
                    return 0; // Don't seed if data already exists
                }

                var sampleCustomers = GetSampleCustomers();
                
                _context.Customers.AddRange(sampleCustomers);
                await _context.SaveChangesAsync();

                return sampleCustomers.Count;
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Error seeding database: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Forces database seeding (clears existing data first)
        /// </summary>
        /// <returns>Number of customers created</returns>
        public async Task<int> ForceSeedDatabaseAsync()
        {
            try
            {
                // Clear existing data
                var existingCustomers = await _context.Customers.ToListAsync();
                _context.Customers.RemoveRange(existingCustomers);
                await _context.SaveChangesAsync();

                // Add sample data
                var sampleCustomers = GetSampleCustomers();
                _context.Customers.AddRange(sampleCustomers);
                await _context.SaveChangesAsync();

                return sampleCustomers.Count;
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Error force seeding database: {ex.Message}", ex);
            }
        }

        #endregion

        #region Helper Methods

        /// <summary>
        /// Validates customer data
        /// </summary>
        /// <param name="customer">Customer to validate</param>
        /// <returns>List of validation error messages</returns>
        private List<string> ValidateCustomer(Customer customer)
        {
            var errors = new List<string>();

            if (string.IsNullOrWhiteSpace(customer.FirstName))
                errors.Add("First name is required");
            else if (customer.FirstName.Length > 50)
                errors.Add("First name cannot exceed 50 characters");

            if (string.IsNullOrWhiteSpace(customer.LastName))
                errors.Add("Last name is required");
            else if (customer.LastName.Length > 50)
                errors.Add("Last name cannot exceed 50 characters");

            if (string.IsNullOrWhiteSpace(customer.Email))
                errors.Add("Email is required");
            else if (customer.Email.Length > 100)
                errors.Add("Email cannot exceed 100 characters");
            else if (!IsValidEmail(customer.Email))
                errors.Add("Please enter a valid email address");

            if (!string.IsNullOrWhiteSpace(customer.Phone) && customer.Phone.Length > 20)
                errors.Add("Phone number cannot exceed 20 characters");

            return errors;
        }

        /// <summary>
        /// Validates email format
        /// </summary>
        /// <param name="email">Email to validate</param>
        /// <returns>True if valid email format</returns>
        private bool IsValidEmail(string email)
        {
            try
            {
                var addr = new System.Net.Mail.MailAddress(email);
                return addr.Address == email;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Generates sample customer data for seeding
        /// </summary>
        /// <returns>List of sample customers</returns>
        private List<Customer> GetSampleCustomers()
        {
            var now = DateTime.UtcNow;
            
            return new List<Customer>
            {
                new Customer { FirstName = "John", LastName = "Smith", Email = "john.smith@example.com", Phone = "+1-555-0101", DateCreated = now.AddDays(-30), DateModified = now.AddDays(-30) },
                new Customer { FirstName = "Jane", LastName = "Johnson", Email = "jane.johnson@example.com", Phone = "+1-555-0102", DateCreated = now.AddDays(-25), DateModified = now.AddDays(-25) },
                new Customer { FirstName = "Michael", LastName = "Brown", Email = "michael.brown@example.com", Phone = "+1-555-0103", DateCreated = now.AddDays(-20), DateModified = now.AddDays(-20) },
                new Customer { FirstName = "Emily", LastName = "Davis", Email = "emily.davis@example.com", Phone = "+1-555-0104", DateCreated = now.AddDays(-18), DateModified = now.AddDays(-18) },
                new Customer { FirstName = "David", LastName = "Wilson", Email = "david.wilson@example.com", Phone = "+1-555-0105", DateCreated = now.AddDays(-15), DateModified = now.AddDays(-15) },
                new Customer { FirstName = "Sarah", LastName = "Miller", Email = "sarah.miller@example.com", Phone = "+1-555-0106", DateCreated = now.AddDays(-12), DateModified = now.AddDays(-12) },
                new Customer { FirstName = "Robert", LastName = "Anderson", Email = "robert.anderson@example.com", Phone = "+1-555-0107", DateCreated = now.AddDays(-10), DateModified = now.AddDays(-10) },
                new Customer { FirstName = "Lisa", LastName = "Taylor", Email = "lisa.taylor@example.com", Phone = "+1-555-0108", DateCreated = now.AddDays(-8), DateModified = now.AddDays(-8) },
                new Customer { FirstName = "Christopher", LastName = "Thomas", Email = "christopher.thomas@example.com", Phone = "+1-555-0109", DateCreated = now.AddDays(-5), DateModified = now.AddDays(-5) },
                new Customer { FirstName = "Amanda", LastName = "Garcia", Email = "amanda.garcia@example.com", Phone = "+1-555-0110", DateCreated = now.AddDays(-3), DateModified = now.AddDays(-3) },
                new Customer { FirstName = "James", LastName = "Martinez", Email = "james.martinez@example.com", Phone = "+1-555-0111", DateCreated = now.AddDays(-2), DateModified = now.AddDays(-2) },
                new Customer { FirstName = "Jennifer", LastName = "Robinson", Email = "jennifer.robinson@example.com", Phone = "+1-555-0112", DateCreated = now.AddDays(-1), DateModified = now.AddDays(-1) },
                new Customer { FirstName = "William", LastName = "Clark", Email = "william.clark@example.com", Phone = "+1-555-0113", DateCreated = now, DateModified = now },
                new Customer { FirstName = "Mary", LastName = "Rodriguez", Email = "mary.rodriguez@example.com", Phone = "+1-555-0114", DateCreated = now, DateModified = now },
                new Customer { FirstName = "Joseph", LastName = "Lewis", Email = "joseph.lewis@example.com", Phone = "+1-555-0115", DateCreated = now, DateModified = now }
            };
        }

        #endregion

        #region Dispose Pattern

        /// <summary>
        /// Disposes the service and its resources
        /// </summary>
        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        /// <summary>
        /// Protected dispose method
        /// </summary>
        /// <param name="disposing">True if disposing managed resources</param>
        protected virtual void Dispose(bool disposing)
        {
            if (!_disposed)
            {
                if (disposing)
                {
                    _context?.Dispose();
                }
                _disposed = true;
            }
        }

        #endregion
    }
}