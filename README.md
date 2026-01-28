# Database Documentation
Below is all necessary information regarding the database design, implementation and use. All database testing has been done with MySQL Server 8.0.44

### Notes
- The database for the app is currently hosted on AWS. Testing can be done locally, instructions for both use cases are provided. 

### Running database instructions
1. Download MySQL from here: https://dev.mysql.com/downloads/file/?id=546163, make sure you're downloading MySQL 8.0.44.0
2. Follow the installer setup
3. Run this command in terminal to connect to the server (If you installed MySQL in a different location, use your path to mysql.exe or mysql for Mac):
   
    - Windows:
      - Local:
   
           ```
           & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p
           ```
           
        - AWS:
          
          ```
          & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -h identiflora.crwyoycsq98a.us-west-1.rds.amazonaws.com -P 3306 -u admin -p
          ```

       - On Mac:
           - Local:
           
             ```
             /usr/local/mysql/bin/mysql -u root -p
             ```
           - AWS:

             ```
             /usr/local/mysql/bin/mysql -h identiflora.crwyoycsq98a.us-west-1.rds.amazonaws.com -P 3306 -u admin -p
             ```

   
5. To build the database on your machine, run: 'SOURCE initialize_database.sql;'
6. The above format can be used to run any .sql file from the mysql terminal.

## Tables
### plant_species
One entry exists for each plant the model is able to identify.

- **species_id**
  - **Datatype -** int
  - **Description -** auto-incrementing primary key identifier.
- **common_name**
  - **Datatype -** varchar(255)
  - **Description -** common name of the plant.
- **scientific_name**
  - **Datatype -** varchar(255)
  - **Description -** scientific (Latin) species name of the plant.
- **genus**
  - **Datatype -** varchar(255)
  - **Description -** genus to which the plant belongs.
- **img_url**
  - **Datatype -** varchar(512)
  - **Description -** URL to an example reference image of the plant.

---

### identification_submission
Entry is created when a user submits a photo for identification. 

- **identification_id**
  - **Datatype -** int
  - **Description -** auto-incrementing primary key identifier.
- **img_url**
  - **Datatype -** varchar(512)
  - **Description -** URL to the image the user submitted. 
- **user_id**
  - **Datatype -** int
  - **Description -** references the PK identifier of the user that submitted the photo. 
- **time_submitted**
  - **Datatype -** timestamp
  - **Description -** time when the entry was added to the database. 

---

### identification_option
Specifies one possible species option for an identification submission. Each submission may have up to five ranked options.

- **option_id**
  - **Datatype -** int
  - **Description -** auto-incrementing primary key identifier for an option.
- **identification_id**
  - **Datatype -** int
  - **Description -** Foreign key, references the submission this option belongs to.
- **species_id**
  - **Datatype -** int
  - **Description -** Foreign key, references the plant species associated with this option.
- **rank**
  - **Datatype -** int
  - **Description -** position of this option within the N-best list (1-5), ensuring each rank is unique per submission.

**Additional Constraints**
- Each option for a submission must have a unique **rank**.  
- Each option for a submission must reference a unique **species**.  
- Cascading deletes ensure options are removed when their submission or species is deleted.

---

### identification_result
Stores the final chosen result (best-ranked) for an identification submission. Each submission may have at most one result.

- **identification_id**
  - **Datatype -** int
  - **Description -** primary key, foreign key referencing the submission. Guarantees one result per submission.
- **option_id**
  - **Datatype -** int
  - **Description -** references the selected option that was chosen for final result.

**Additional Constraints**
- Ensures the chosen option belongs to the same submission by enforcing the composite foreign key **(identification_id, option_id)**. This ensures that the option_id references an option that is associated with the correct submission.
- Cascading deletes ensure results are removed automatically if the associated submission or option is deleted.

---

### incorrect_identification
Stores a user-reported incorrect prediction for a submission.

- **identification_id**
  - **Datatype -** int
  - **Description -** primary key; FK to identification_submission.
- **correct_species_id**
  - **Datatype -** int
  - **Description -** FK to plant_species (true species).
- **incorrect_species_id**
  - **Datatype -** int
  - **Description -** FK to plant_species (model-predicted species).
- **time_submitted**
  - **Datatype -** timestamp
  - **Description -** time when the incorrect report was added.

**Additional Constraints**
- Composite FK **(identification_id, incorrect_species_id)** must match an option in **identification_option** (ensures the reported incorrect species was one of the model's options for that submission).
- Cascading deletes clean up rows if submissions or species are removed.