using System;
using System.Data.Entity;
using System.Data.Entity.ModelConfiguration.Conventions;
using System.Threading.Tasks;

namespace SampleApi.Models
{
    /// <summary>
    /// Entity Framework Database Context for the Sample API
    /// </summary>
    public class DatabaseContext : DbContext
    {
        /// <summary>
        /// Customers table
        /// </summary>
        public DbSet<Customer> Customers { get; set; }

        /// <summary>
        /// Constructor - uses the DefaultConnection connection string from web.config
        /// </summary>
        public DatabaseContext() : base("DefaultConnection")
        {
            // Enable automatic database creation and migration
            Database.SetInitializer(new CreateDatabaseIfNotExists<DatabaseContext>());
            
            // Optional: Enable logging for debugging
            Database.Log = System.Diagnostics.Debug.WriteLine;
        }

        /// <summary>
        /// Model configuration and relationships
        /// </summary>
        protected override void OnModelCreating(DbModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Remove pluralizing table name convention
            modelBuilder.Conventions.Remove<PluralizingTableNameConvention>();

            // Customer entity configuration
            modelBuilder.Entity<Customer>()
                .HasKey(c => c.Id);

            modelBuilder.Entity<Customer>()
                .Property(c => c.Id)
                .HasDatabaseGeneratedOption(System.ComponentModel.DataAnnotations.Schema.DatabaseGeneratedOption.Identity);

            modelBuilder.Entity<Customer>()
                .Property(c => c.FirstName)
                .IsRequired()
                .HasMaxLength(50);

            modelBuilder.Entity<Customer>()
                .Property(c => c.LastName)
                .IsRequired()
                .HasMaxLength(50);

            modelBuilder.Entity<Customer>()
                .Property(c => c.Email)
                .IsRequired()
                .HasMaxLength(100);

            modelBuilder.Entity<Customer>()
                .HasIndex(c => c.Email)
                .IsUnique()
                .HasName("IX_Customer_Email");

            modelBuilder.Entity<Customer>()
                .Property(c => c.Phone)
                .HasMaxLength(20);

            modelBuilder.Entity<Customer>()
                .Property(c => c.DateCreated)
                .IsRequired()
                .HasDatabaseGeneratedOption(System.ComponentModel.DataAnnotations.Schema.DatabaseGeneratedOption.Identity);

            modelBuilder.Entity<Customer>()
                .Property(c => c.DateModified)
                .IsRequired();
        }

        /// <summary>
        /// Override SaveChanges to automatically update DateModified
        /// </summary>
        public override int SaveChanges()
        {
            UpdateTimestamps();
            return base.SaveChanges();
        }

        /// <summary>
        /// Override SaveChangesAsync to automatically update DateModified
        /// </summary>
        public override async Task<int> SaveChangesAsync()
        {
            UpdateTimestamps();
            return await base.SaveChangesAsync();
        }

        /// <summary>
        /// Updates the DateModified timestamp for modified entities
        /// </summary>
        private void UpdateTimestamps()
        {
            var entries = ChangeTracker.Entries<Customer>();
            
            foreach (var entry in entries)
            {
                if (entry.State == EntityState.Modified)
                {
                    entry.Entity.UpdateModifiedDate();
                }
                else if (entry.State == EntityState.Added)
                {
                    entry.Entity.DateCreated = DateTime.UtcNow;
                    entry.Entity.DateModified = DateTime.UtcNow;
                }
            }
        }

        /// <summary>
        /// Dispose pattern implementation
        /// </summary>
        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                // Dispose managed resources
            }
            base.Dispose(disposing);
        }
    }
}