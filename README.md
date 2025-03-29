# SQL Scripts Collection

This repository contains a collection of SQL scripts that demonstrate various database design, analysis, and manipulation techniques using PostgreSQL. These scripts are designed to showcase database skills relevant to e-commerce applications but can be adapted for other domains.

## Overview

The repository contains three main SQL script files:

1. **Database Schema Design and Setup** - Creates a normalized database schema with relationships, constraints, triggers, and views
2. **Advanced Data Analysis Script** - Demonstrates complex SQL queries for business intelligence and analytics
3. **Data Manipulation and Procedures** - Implements CRUD operations, transactions, and business logic through stored procedures and functions

## 1. Database Schema Design and Setup

This script focuses on creating a well-structured, normalized database schema for an e-commerce application. It demonstrates:

- **Proper table design** with appropriate data types and constraints
- **Normalization principles** to reduce redundancy and maintain data integrity
- **Relationships between tables** using primary and foreign keys
- **Indexing strategies** to optimize query performance
- **Triggers** for automating data updates and maintaining consistency
- **Views** for simplified data access and encapsulation
- **Documentation** through comments on tables and columns

### Key Features

- UUID primary keys for security and distributed systems compatibility
- Comprehensive constraint system including check constraints and unique constraints
- Automatic timestamp management for auditing
- Materialized views for caching expensive query results
- Inventory management with automatic alerts
- Functions for common operations like customer search

## 2. Advanced Data Analysis Script

This script showcases complex SQL queries that transform raw data into actionable business insights. It demonstrates:

- **Common Table Expressions (CTEs)** for query modularization
- **Window functions** for advanced analytics like growth rates and rankings
- **Statistical analysis** including correlation and standard deviation calculations
- **Cohort analysis** for customer retention metrics
- **Segmentation techniques** for customer and product categorization

### Key Analyses

- Sales tracking by category with month-over-month growth and performance indicators
- Customer segmentation based on purchase frequency, recency, and monetary value
- Product performance analysis with price sensitivity correlation
- Cohort-based retention analysis to track customer loyalty over time

## 3. Data Manipulation and Procedures

This script demonstrates how to implement business logic and data manipulation through stored procedures and functions. It showcases:

- **Stored procedures** for encapsulating complex operations
- **Transaction management** with proper error handling and rollback
- **JSON processing** for handling complex data structures
- **Dynamic SQL** for flexible operations
- **Business rule implementation** through procedural code

### Key Procedures and Functions

- Complete order creation with inventory verification and customer loyalty tracking
- Product recommendation engine based on purchase history and popularity
- Order status management with customer notifications
- Bulk price updates with constraints and previews
- Customer purchase analysis with segmentation
- Product return processing with inventory adjustments

## Use Cases

These scripts can be used for:

1. **Learning and reference** - Study advanced SQL techniques and patterns
2. **Portfolio demonstration** - Showcase database design and SQL proficiency
3. **Project templates** - Adapt for real-world applications
4. **Interview preparation** - Practice complex SQL problems

## Technologies Used

- PostgreSQL 12+
- SQL features:
  - Common Table Expressions (CTEs)
  - Window functions
  - JSON/JSONB data types
  - Materialized views
  - Stored procedures and functions
  - Triggers
  - Transaction management

## Getting Started

1. Ensure you have PostgreSQL 12 or later installed
2. Create a new database for testing
3. Run the schema setup script first to create the database structure
4. Run the data manipulation script to add sample data and create procedures
5. Execute the analysis script to see the analytical queries in action

## Notes on Customization

These scripts are designed to be educational and showcase various SQL techniques. In a production environment, you would want to:

- Add more extensive error handling
- Optimize queries for your specific data volumes and access patterns
- Add security measures like row-level security and proper user permissions
- Consider partitioning for very large tables
- Implement a more sophisticated backup and maintenance strategy

## License

These scripts are provided under the MIT License. Feel free to use, modify, and distribute them as needed.
