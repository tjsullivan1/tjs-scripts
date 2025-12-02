using System;
using System.Collections.Generic;

namespace SampleApi.Models
{
    /// <summary>
    /// Standard API response wrapper for consistent response format across all endpoints
    /// </summary>
    /// <typeparam name="T">The type of data being returned</typeparam>
    public class ApiResponse<T>
    {
        /// <summary>
        /// Indicates whether the operation was successful
        /// </summary>
        public bool Success { get; set; }

        /// <summary>
        /// Human-readable message describing the result
        /// </summary>
        public string Message { get; set; }

        /// <summary>
        /// The actual data payload
        /// </summary>
        public T Data { get; set; }

        /// <summary>
        /// Collection of error messages if any occurred
        /// </summary>
        public List<string> Errors { get; set; }

        /// <summary>
        /// Timestamp when the response was generated
        /// </summary>
        public DateTime Timestamp { get; set; }

        /// <summary>
        /// Additional metadata about the response (e.g., pagination info)
        /// </summary>
        public object Metadata { get; set; }

        public ApiResponse()
        {
            Errors = new List<string>();
            Timestamp = DateTime.UtcNow;
        }

        /// <summary>
        /// Creates a successful response with data
        /// </summary>
        public static ApiResponse<T> SuccessResponse(T data, string message = "Operation completed successfully")
        {
            return new ApiResponse<T>
            {
                Success = true,
                Message = message,
                Data = data,
                Errors = new List<string>(),
                Timestamp = DateTime.UtcNow
            };
        }

        /// <summary>
        /// Creates a successful response with data and metadata
        /// </summary>
        public static ApiResponse<T> SuccessResponse(T data, object metadata, string message = "Operation completed successfully")
        {
            return new ApiResponse<T>
            {
                Success = true,
                Message = message,
                Data = data,
                Metadata = metadata,
                Errors = new List<string>(),
                Timestamp = DateTime.UtcNow
            };
        }

        /// <summary>
        /// Creates an error response with error messages
        /// </summary>
        public static ApiResponse<T> ErrorResponse(string message, List<string> errors = null)
        {
            return new ApiResponse<T>
            {
                Success = false,
                Message = message,
                Data = default(T),
                Errors = errors ?? new List<string>(),
                Timestamp = DateTime.UtcNow
            };
        }

        /// <summary>
        /// Creates an error response with a single error message
        /// </summary>
        public static ApiResponse<T> ErrorResponse(string message, string error)
        {
            return new ApiResponse<T>
            {
                Success = false,
                Message = message,
                Data = default(T),
                Errors = new List<string> { error },
                Timestamp = DateTime.UtcNow
            };
        }

        /// <summary>
        /// Creates a validation error response
        /// </summary>
        public static ApiResponse<T> ValidationErrorResponse(List<string> validationErrors)
        {
            return new ApiResponse<T>
            {
                Success = false,
                Message = "Validation failed",
                Data = default(T),
                Errors = validationErrors ?? new List<string>(),
                Timestamp = DateTime.UtcNow
            };
        }

        /// <summary>
        /// Creates a not found response
        /// </summary>
        public static ApiResponse<T> NotFoundResponse(string message = "Resource not found")
        {
            return new ApiResponse<T>
            {
                Success = false,
                Message = message,
                Data = default(T),
                Errors = new List<string>(),
                Timestamp = DateTime.UtcNow
            };
        }
    }

    /// <summary>
    /// Non-generic version for responses without data payload
    /// </summary>
    public class ApiResponse : ApiResponse<object>
    {
        /// <summary>
        /// Creates a simple success response without data
        /// </summary>
        public static ApiResponse SuccessResponse(string message = "Operation completed successfully")
        {
            return new ApiResponse
            {
                Success = true,
                Message = message,
                Data = null,
                Errors = new List<string>(),
                Timestamp = DateTime.UtcNow
            };
        }
    }
}