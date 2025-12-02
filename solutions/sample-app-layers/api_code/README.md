# Sample API - .NET Framework 4.8

A sample Web API built with .NET Framework 4.8 that provides customer data management with SQL Server integration.

## Features

- **Customer Management API**: Full CRUD operations for customer data
- **Database Seeding**: Endpoint to populate database with sample data
- **SQL Server Integration**: Entity Framework 6 for data access
- **JSON API**: RESTful endpoints with JSON responses
- **CORS Support**: Cross-origin resource sharing enabled

## API Endpoints

### Seed Data
- `GET /api/seed` - Creates sample customer data in the database

### Customer Management
- `GET /api/customers` - Retrieve all customers
- `GET /api/customers/{id}` - Get specific customer by ID
- `POST /api/customers` - Create new customer
- `PUT /api/customers/{id}` - Update existing customer
- `DELETE /api/customers/{id}` - Delete customer

## Project Structure

```
SampleApi/
├── App_Start/              # Application startup configuration
│   ├── WebApiConfig.cs     # Web API routing and formatting
│   └── FilterConfig.cs     # Global filters
├── Controllers/            # API controllers
│   ├── CustomersController.cs  # Customer CRUD endpoints
│   └── SeedController.cs       # Database seeding
├── Models/                 # Data models and context
│   ├── Customer.cs         # Customer entity
│   ├── DatabaseContext.cs # Entity Framework context
│   └── ApiResponse.cs      # Standard API response format
├── Services/               # Business logic layer
│   └── CustomerService.cs  # Customer business operations
├── Properties/
│   └── AssemblyInfo.cs     # Assembly metadata
├── Global.asax(.cs)        # Application entry point
├── Web.config              # Application configuration
└── packages.config         # NuGet package references
```

## Dependencies

- **Microsoft.AspNet.WebApi** (5.2.9) - Web API framework
- **EntityFramework** (6.4.4) - Object-relational mapping
- **Newtonsoft.Json** (13.0.3) - JSON serialization
- **Microsoft.AspNet.WebApi.Cors** (5.2.9) - CORS support

## Configuration

### Connection String
Update the connection string in `Web.config`:

```xml
<connectionStrings>
  <add name="DefaultConnection" 
       connectionString="your-connection-string-here" 
       providerName="System.Data.SqlClient" />
</connectionStrings>
```

For Azure SQL Database:
```xml
<add name="DefaultConnection" 
     connectionString="Server=tcp:your-server.database.windows.net,1433;Initial Catalog=your-database;Persist Security Info=False;User ID=your-username;Password=your-password;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" 
     providerName="System.Data.SqlClient" />
```

## Development

### Prerequisites
- Visual Studio 2019/2022 or VS Code
- .NET Framework 4.8
- SQL Server (Local or Azure)

### Running Locally
1. Update connection string in `Web.config`
2. Build the solution
3. Run the application (F5 in Visual Studio)
4. Navigate to `/api/seed` to initialize sample data
5. Use `/api/customers` endpoints to manage data

### Database Schema
The application will automatically create the following table:

```sql
CREATE TABLE Customers (
    Id int IDENTITY(1,1) PRIMARY KEY,
    FirstName nvarchar(50) NOT NULL,
    LastName nvarchar(50) NOT NULL,
    Email nvarchar(100) NOT NULL,
    Phone nvarchar(20),
    DateCreated datetime2 DEFAULT GETDATE(),
    DateModified datetime2 DEFAULT GETDATE()
);
```

## Deployment

### Azure App Service
1. Publish the application using Visual Studio
2. Configure connection string in App Service Configuration
3. Ensure SQL Server firewall allows App Service access

### Manual Deployment
1. Build in Release mode
2. Copy contents of `bin/` and web files to server
3. Configure IIS application pool for .NET Framework 4.8
4. Set up connection string in web.config

## API Response Format

All endpoints return responses in this format:

```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": { ... },
  "errors": []
}
```

## Error Handling

- Input validation with meaningful error messages
- Global exception handling
- Consistent HTTP status codes
- Detailed error logging

---

*This is a sample application demonstrating .NET Framework 4.8 Web API patterns with Entity Framework and SQL Server integration.*