DROP DATABASE IF EXISTS `paw-match-db`;
CREATE DATABASE IF NOT EXISTS `paw-match-db`;
USE `paw-match-db`;

CREATE TABLE animal (
   animal_id INT AUTO_INCREMENT PRIMARY KEY,
   name VARCHAR(50),
   age_months INT,
   intake_date DATE,
   status ENUM('Available', 'Adopted', 'Pending Adoption', 'Fostered', 'Medical Hold') NOT NULL DEFAULT 'Available',
   species ENUM('Dog', 'Cat', 'Rabbit', 'Other') NOT NULL,
   breed VARCHAR(100),
   flagged BOOLEAN NOT NULL DEFAULT FALSE,
   INDEX idx_status (status),
   INDEX idx_species (species)
);


CREATE TABLE adopter (
   adopter_id INT AUTO_INCREMENT PRIMARY KEY,
   first_name VARCHAR(50),
   last_name VARCHAR(50),
   email VARCHAR(75) NOT NULL UNIQUE,
   phone VARCHAR(15) UNIQUE,
   address VARCHAR(100),
   INDEX idx_email (email),
   INDEX idx_last_name (last_name)
);


CREATE TABLE employee (
  employee_id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(50),
  last_name VARCHAR(50),
  email VARCHAR(75),
  password VARCHAR(75),
  address VARCHAR(100),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email (email)
);


CREATE TABLE employee_role(
 employee_id INT NOT NULL,
 role ENUM('Volunteer', 'Staff', 'Analyst', 'Other') NOT NULL,
 permissions SET('view_animals', 'edit_animals', 'manage_adoptions', 'view_reports', 'manage_employees') NOT NULL,
 PRIMARY KEY (employee_id),
 FOREIGN KEY (employee_id) REFERENCES employee(employee_id)
);


CREATE TABLE audit_log(
 log_id INT AUTO_INCREMENT PRIMARY KEY,
 animal_id INT,
 employee_id INT,
 adopter_id INT,
 action ENUM('Created', 'Updated', 'Deleted', 'Status Change'),
 old_value TEXT,
 new_value TEXT,
 field_changed VARCHAR(100),
 changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT fk_audit_animal
     FOREIGN KEY (animal_id) REFERENCES animal(animal_id),
 CONSTRAINT fk_audit_employee
   FOREIGN KEY (employee_id) REFERENCES employee(employee_id),
 CONSTRAINT fk_audit_adopter
   FOREIGN KEY (adopter_id) REFERENCES adopter(adopter_id),
 INDEX idx_changed_at (changed_at),
 INDEX idx_action (action)
);


CREATE TABLE application (
  application_id INT AUTO_INCREMENT PRIMARY KEY,
  adopter_id INT NOT NULL,
  animal_id INT NOT NULL,
  status ENUM('Pending', 'Under Review', 'Approved', 'Denied', 'Withdrawn', 'Completed') NOT NULL,
  notes TEXT,
  submission_date DATE NOT NULL,
  decision_date DATE,
  INDEX idx_status (status),
  CONSTRAINT fk_application_adopter
          FOREIGN KEY (adopter_id) REFERENCES adopter (adopter_id),
  CONSTRAINT fk_application_animal
          FOREIGN KEY (animal_id) REFERENCES animal (animal_id)
);




CREATE TABLE medical_record (
  record_id INT AUTO_INCREMENT PRIMARY KEY,
  notes TEXT,
  practitioner_name VARCHAR(100),
  admin_date DATE NOT NULL,
  category ENUM('Vaccination', 'Surgery', 'Medication', 'Checkup', 'Treatment', 'Spay/Neuter'),
  animal_id INT NOT NULL,
  INDEX idx_admin_date (admin_date),
  INDEX idx_category (category),
  CONSTRAINT fk_medical_record_animal
          FOREIGN KEY (animal_id) REFERENCES animal (animal_id)
);




CREATE TABLE foster_placement (
  placement_id INT AUTO_INCREMENT PRIMARY KEY,
  adopter_id INT,
  animal_id INT NOT NULL,
  health_notes TEXT,
  behavior_notes TEXT,
  start_date DATE NOT NULL,
  end_date DATE,
  duration INT AS (DATEDIFF(end_date, start_date)) VIRTUAL,
  return_reason ENUM('Adoption Ready', 'Medical Concern', 'Behavioral Issue', 'Foster Unable to Continue', 'End of Foster Period', 'Other'),
  INDEX idx_start_date(start_date),
  INDEX idx_end_date(end_date),
  CONSTRAINT fk_foster_placement_animal
       FOREIGN KEY (animal_id) REFERENCES animal (animal_id),
   CONSTRAINT fk_foster_placement_adopter
       FOREIGN KEY (adopter_id) REFERENCES adopter(adopter_id)
);


CREATE TABLE compatibility_quiz (
   quiz_id INT AUTO_INCREMENT PRIMARY KEY,
   adopter_id INT NOT NULL,
   activity_level INT NOT NULL CHECK (activity_level BETWEEN 1 AND 10),
   energy_pref ENUM('Low', 'Medium', 'High'),
   size_pref ENUM('Small', 'Midsize', 'Large'),
   living_situation ENUM('Apartment', 'House', 'Other'),
   date_taken DATE NOT NULL DEFAULT (CURRENT_DATE),
   CONSTRAINT fk_quiz_adopter
       FOREIGN KEY (adopter_id) REFERENCES adopter(adopter_id)
);


CREATE TABLE quiz_rec (
   rec_id INT AUTO_INCREMENT PRIMARY KEY,
   quiz_id INT NOT NULL,
   animal_id INT NOT NULL,
   compatibility_score INT NOT NULL CHECK(compatibility_score BETWEEN 1 AND 100),
   CONSTRAINT fk_rec_quiz
       FOREIGN KEY (quiz_id) REFERENCES compatibility_quiz(quiz_id),
   CONSTRAINT fk_rec_animal
       FOREIGN KEY (animal_id) REFERENCES animal(animal_id)
);


CREATE TABLE report_template (
   template_id INT AUTO_INCREMENT PRIMARY KEY,
   template_name VARCHAR(75) NOT NULL,
   is_archived BOOLEAN NOT NULL DEFAULT FALSE,
   export_format ENUM('PDF', 'CSV', 'Excel') NOT NULL DEFAULT 'PDF',
   metric_included SET('Total Adopted', 'Average Days to Adopt', 'Average Length of Stay', 'Species Breakdown', 'Intake Count') NOT NULL,
   date_range_start DATE NOT NULL,
   date_range_end DATE NOT NULL
);


CREATE TABLE monthly_report(
   report_id INT AUTO_INCREMENT PRIMARY KEY,
   template_id INT,
   report_month DATE NOT NULL,
   generated_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
   total_adopted INT NOT NULL DEFAULT 0,
   avg_days_to_adopt DECIMAL(6, 2),
   avg_length_of_stay DECIMAL(6, 2),
   CONSTRAINT fk_report_template
       FOREIGN KEY (template_id) REFERENCES report_template(template_id),
   CONSTRAINT uq_report_month UNIQUE (report_month)
);


CREATE TABLE adoption (
   adoption_id INT AUTO_INCREMENT PRIMARY KEY,
   application_id INT NOT NULL,
   report_id INT,
   adoption_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
   outcome ENUM('Adopted', 'Returned', 'Fostered') NOT NULL DEFAULT 'Adopted',
   days_to_adopt INT,
   return_flag BOOLEAN NOT NULL DEFAULT FALSE,
   CONSTRAINT fk_adoption_application
       FOREIGN KEY (application_id) REFERENCES application(application_id),
   CONSTRAINT fk_adoption_report
       FOREIGN KEY (report_id) REFERENCES monthly_report(report_id),
   CONSTRAINT uq_adoption_application UNIQUE (application_id),
   INDEX idx_adoption_date (adoption_date),
   INDEX idx_outcome (outcome)
);


CREATE TABLE meet_appointment (
   appointment_id INT AUTO_INCREMENT PRIMARY KEY,
   adopter_id INT NOT NULL,
   animal_id INT NOT NULL,
   status ENUM('Scheduled', 'Completed', 'Cancelled', 'No Show') NOT NULL DEFAULT 'Scheduled',
   scheduled_for DATETIME NOT NULL,
   notes TEXT,
   CONSTRAINT fk_meet_adopter
       FOREIGN KEY (adopter_id) REFERENCES adopter(adopter_id),
   CONSTRAINT fk_meet_animal
       FOREIGN KEY (animal_id) REFERENCES animal(animal_id),
   INDEX idx_scheduled_for (scheduled_for),
   INDEX idx_status (status)
);


CREATE TABLE success_story (
   story_id INT AUTO_INCREMENT PRIMARY KEY,
   adopter_id INT NOT NULL,
   animal_id INT,
   rating INT NOT NULL CHECK (rating BETWEEN 1 AND 10),
   is_reviewed BOOLEAN NOT NULL DEFAULT FALSE,
   content TEXT NOT NULL,
   posted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
   CONSTRAINT fk_story_adopter
       FOREIGN KEY (adopter_id) REFERENCES adopter(adopter_id) ON DELETE CASCADE,
   CONSTRAINT fk_story_animal
       FOREIGN KEY (animal_id) REFERENCES animal(animal_id) ON DELETE SET NULL,
   INDEX idx_is_reviewed (is_reviewed)
);
