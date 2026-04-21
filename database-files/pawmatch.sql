-- ============================================================
-- PawMatch Database DDL
-- ============================================================
-- NOTE: Mock data dates are in M/D/YYYY format.
-- MySQL requires YYYY-MM-DD. Either:
--   a) Reformat dates in the mock data to YYYY-MM-DD, OR
--   b) Wrap each date value in STR_TO_DATE('val', '%c/%e/%Y')
-- ============================================================

DROP DATABASE IF EXISTS PawMatch;
CREATE DATABASE IF NOT EXISTS PawMatch;
USE PawMatch;

-- ------------------------------------------------------------
-- animal
-- ------------------------------------------------------------
CREATE TABLE animal (
    animal_id       INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(50),
    age_months      INT,
    size            ENUM('Small', 'Midsize', 'Large'),
    energy_level    ENUM('Low', 'Medium', 'High'),
    intake_date     DATE,
    status          ENUM('Available', 'Adopted', 'Pending Adoption', 'Fostered', 'Medical Hold')
                    NOT NULL DEFAULT 'Available',
    species         ENUM('Dog', 'Cat', 'Rabbit', 'Other') NOT NULL,
    breed           VARCHAR(100),
    flagged         BOOLEAN NOT NULL DEFAULT FALSE,
    INDEX idx_status  (status),
    INDEX idx_species (species)
);

-- ------------------------------------------------------------
-- adopter
-- ------------------------------------------------------------
CREATE TABLE adopter (
    adopter_id  INT AUTO_INCREMENT PRIMARY KEY,
    first_name  VARCHAR(50),
    last_name   VARCHAR(50),
    email       VARCHAR(75) NOT NULL UNIQUE,
    phone       VARCHAR(15),
    address     VARCHAR(100),
    INDEX idx_email     (email),
    INDEX idx_last_name (last_name)
);

-- ------------------------------------------------------------
-- employee
-- ------------------------------------------------------------
CREATE TABLE employee (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name  VARCHAR(50),
    last_name   VARCHAR(50),
    email       VARCHAR(75),
    password    VARCHAR(75),
    address     VARCHAR(100),
    created_at  DATE NOT NULL DEFAULT (CURRENT_DATE),
    INDEX idx_email (email)
);

-- ------------------------------------------------------------
-- employee_role
-- ------------------------------------------------------------
CREATE TABLE employee_role (
    employee_id INT NOT NULL,
    role        ENUM('Volunteer', 'Staff', 'Analyst', 'Admin', 'Other') NOT NULL,
    permissions SET('view_animals', 'edit_animals', 'manage_adoptions',
                    'view_reports', 'manage_employees') NOT NULL,
    PRIMARY KEY (employee_id),
    CONSTRAINT fk_employee_role_employee
        FOREIGN KEY (employee_id) REFERENCES employee (employee_id)
        ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- audit_log
-- ------------------------------------------------------------
CREATE TABLE audit_log (
    log_id        INT AUTO_INCREMENT PRIMARY KEY,
    animal_id     INT,
    employee_id   INT,
    adopter_id    INT,
    action        ENUM('Created', 'Updated', 'Deleted', 'Status Change'),
    old_value     TEXT,
    new_value     TEXT,
    field_changed VARCHAR(100),
    changed_at    DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT fk_audit_animal
        FOREIGN KEY (animal_id)   REFERENCES animal   (animal_id),
    CONSTRAINT fk_audit_employee
        FOREIGN KEY (employee_id) REFERENCES employee  (employee_id),
    CONSTRAINT fk_audit_adopter
        FOREIGN KEY (adopter_id)  REFERENCES adopter   (adopter_id),
    INDEX idx_changed_at (changed_at),
    INDEX idx_action     (action)
);

-- ------------------------------------------------------------
-- application
-- ------------------------------------------------------------
CREATE TABLE application (
    application_id  INT AUTO_INCREMENT PRIMARY KEY,
    adopter_id      INT NOT NULL,
    animal_id       INT NOT NULL,
    status          ENUM('Pending', 'Under Review', 'Approved',
                         'Denied', 'Withdrawn', 'Completed') NOT NULL,
    notes           TEXT,
    submission_date DATE NOT NULL,
    decision_date   DATE,
    INDEX idx_status (status),
    CONSTRAINT fk_application_adopter
        FOREIGN KEY (adopter_id) REFERENCES adopter (adopter_id),
    CONSTRAINT fk_application_animal
        FOREIGN KEY (animal_id)  REFERENCES animal  (animal_id)
);

-- ------------------------------------------------------------
-- medical_record
-- NOTE: mock data uses 'Spray/Neuter' — matched here exactly
-- ------------------------------------------------------------
CREATE TABLE medical_record (
    record_id         INT AUTO_INCREMENT PRIMARY KEY,
    notes             TEXT,
    practitioner_name VARCHAR(100),
    admin_date        DATE NOT NULL,
    category          ENUM('Vaccination', 'Surgery', 'Medication',
                           'Checkup', 'Treatment', 'Spray/Neuter'),
    animal_id         INT NOT NULL,
    INDEX idx_admin_date (admin_date),
    INDEX idx_category   (category),
    CONSTRAINT fk_medical_record_animal
        FOREIGN KEY (animal_id) REFERENCES animal (animal_id)
);

-- ------------------------------------------------------------
-- foster_placement
-- ------------------------------------------------------------
CREATE TABLE foster_placement (
    placement_id    INT AUTO_INCREMENT PRIMARY KEY,
    adopter_id      INT,
    animal_id       INT NOT NULL,
    health_notes    TEXT,
    behavior_notes  TEXT,
    start_date      DATE NOT NULL,
    end_date        DATE,
    duration        INT AS (DATEDIFF(end_date, start_date)) VIRTUAL,
    return_reason   ENUM('Adoption Ready', 'Medical Concern', 'Behavioral Issue',
                         'Foster Unable to Continue', 'End of Foster Period', 'Other'),
    INDEX idx_start_date (start_date),
    INDEX idx_end_date   (end_date),
    CONSTRAINT fk_foster_animal
        FOREIGN KEY (animal_id)  REFERENCES animal  (animal_id),
    CONSTRAINT fk_foster_adopter
        FOREIGN KEY (adopter_id) REFERENCES adopter (adopter_id)
);

-- ------------------------------------------------------------
-- compatibility_quiz
-- ------------------------------------------------------------
CREATE TABLE compatibility_quiz (
    quiz_id          INT AUTO_INCREMENT PRIMARY KEY,
    adopter_id       INT NOT NULL,
    energy_pref      ENUM('Low', 'Medium', 'High', 'No Preference'),
    size_pref        ENUM('Small', 'Midsize', 'Large', 'No Preference'),
    species_pref     ENUM('Dog', 'Cat', 'Rabbit', 'No Preference'),
    age_pref         ENUM('Baby', 'Adult', 'Senior', 'No Preference'),
    date_taken       DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT fk_quiz_adopter
        FOREIGN KEY (adopter_id) REFERENCES adopter (adopter_id)
);

-- ------------------------------------------------------------
-- quiz_rec
-- ------------------------------------------------------------
CREATE TABLE quiz_rec (
    rec_id              INT AUTO_INCREMENT PRIMARY KEY,
    quiz_id             INT NOT NULL,
    animal_id           INT NOT NULL,
    compatibility_score INT NOT NULL CHECK (compatibility_score BETWEEN 0 AND 100),
    CONSTRAINT fk_rec_quiz
        FOREIGN KEY (quiz_id)   REFERENCES compatibility_quiz (quiz_id),
    CONSTRAINT fk_rec_animal
        FOREIGN KEY (animal_id) REFERENCES animal             (animal_id)
);

-- ------------------------------------------------------------
-- report_template
-- ------------------------------------------------------------
CREATE TABLE report_template (
    template_id      INT AUTO_INCREMENT PRIMARY KEY,
    template_name    VARCHAR(75) NOT NULL,
    is_archived      BOOLEAN NOT NULL DEFAULT FALSE,
    export_format    ENUM('PDF', 'CSV', 'Excel') NOT NULL DEFAULT 'PDF',
    metric_included  SET('Total Adopted', 'Average Days to Adopt',
                         'Average Length of Stay', 'Species Breakdown',
                         'Intake Count') NOT NULL,
    date_range_start DATE NOT NULL,
    date_range_end   DATE NOT NULL
);

-- ------------------------------------------------------------
-- monthly_report
-- NOTE: FK on template_id is omitted because mock data references
-- template_id values that have no matching report_template rows.
-- Add the FK back once report_template mock data is inserted.
-- ------------------------------------------------------------
CREATE TABLE monthly_report (
    report_id          INT AUTO_INCREMENT PRIMARY KEY,
    template_id        INT,
    report_month       DATE NOT NULL,
    generated_date     DATE NOT NULL DEFAULT (CURRENT_DATE),
    total_adopted      INT NOT NULL DEFAULT 0,
    avg_days_to_adopt  DECIMAL(6, 2),
    avg_length_of_stay DECIMAL(6, 2),
    CONSTRAINT uq_report_month UNIQUE (report_month)
);

-- ------------------------------------------------------------
-- adoption
-- ------------------------------------------------------------
CREATE TABLE adoption (
    adoption_id     INT AUTO_INCREMENT PRIMARY KEY,
    application_id  INT NOT NULL,
    report_id       INT,
    adoption_date   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    outcome         ENUM('Adopted', 'Returned', 'Fostered') NOT NULL DEFAULT 'Adopted',
    days_to_adopt   INT,
    return_flag     BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_adoption_application
        FOREIGN KEY (application_id) REFERENCES application   (application_id),
    CONSTRAINT fk_adoption_report
        FOREIGN KEY (report_id)      REFERENCES monthly_report (report_id),
    CONSTRAINT uq_adoption_application UNIQUE (application_id),
    INDEX idx_adoption_date (adoption_date),
    INDEX idx_outcome       (outcome)
);

-- ------------------------------------------------------------
-- meet_appointment
-- ------------------------------------------------------------
CREATE TABLE meet_appointment (
    appointment_id INT AUTO_INCREMENT PRIMARY KEY,
    adopter_id     INT NOT NULL,
    animal_id      INT NOT NULL,
    status         ENUM('Scheduled', 'Completed', 'Cancelled', 'No Show')
                   NOT NULL DEFAULT 'Scheduled',
    scheduled_for  DATETIME NOT NULL,
    notes          TEXT,
    CONSTRAINT fk_meet_adopter
        FOREIGN KEY (adopter_id) REFERENCES adopter (adopter_id),
    CONSTRAINT fk_meet_animal
        FOREIGN KEY (animal_id)  REFERENCES animal  (animal_id),
    INDEX idx_scheduled_for (scheduled_for),
    INDEX idx_status        (status)
);

-- ------------------------------------------------------------
-- success_story
-- ------------------------------------------------------------
CREATE TABLE success_story (
    story_id    INT AUTO_INCREMENT PRIMARY KEY,
    adopter_id  INT NOT NULL,
    animal_id   INT,
    rating      INT NOT NULL CHECK (rating BETWEEN 1 AND 10),
    is_reviewed BOOLEAN NOT NULL DEFAULT FALSE,
    content     TEXT NOT NULL,
    posted_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_story_adopter
        FOREIGN KEY (adopter_id) REFERENCES adopter (adopter_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_story_animal
        FOREIGN KEY (animal_id)  REFERENCES animal  (animal_id)
        ON DELETE SET NULL,
    INDEX idx_is_reviewed (is_reviewed)
);
USE PawMatch;

insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (1, 'Cherry', 57, 'Small', 'Medium', '2006-02-07', 'Pending Adoption', 'Other', 'Ragdoll', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (2, 'Pebbles', 181, 'Midsize', 'Low', '2012-05-13', 'Medical Hold', 'Rabbit', 'Siamese', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (3, 'Pudding', 195, 'Small', 'High', '2020-05-01', 'Adopted', 'Dog', 'Persian', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (4, 'Honey', 91, 'Large', 'High', '2006-09-30', 'Medical Hold', 'Dog', 'Siamese', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (5, 'Fluffy', 37, 'Midsize', 'Medium', '2011-03-27', 'Pending Adoption', 'Rabbit', 'Golden Retriever', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (6, 'Waffles', 72, 'Large', 'High', '2010-05-09', 'Fostered', 'Other', 'Bengal', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (7, 'Waffles', 106, 'Large', 'High', '2023-03-13', 'Pending Adoption', 'Rabbit', 'Poodle', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (8, 'Pebbles', 119, 'Large', 'Medium', '2005-09-17', 'Medical Hold', 'Dog', 'Persian', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (9, 'Scooter', 176, 'Large', 'Low', '2025-04-12', 'Adopted', 'Rabbit', 'Labrador Retriever', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (10, 'Pudding', 148, 'Small', 'High', '2003-03-26', 'Fostered', 'Rabbit', 'Persian', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (11, 'Peanut', 200, 'Large', 'Low', '2000-03-27', 'Available', 'Rabbit', 'Golden Retriever', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (12, 'Buttercup', 139, 'Large', 'Low', '2023-07-13', 'Pending Adoption', 'Dog', 'Poodle', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (13, 'Peaches', 65, 'Small', 'Medium', '2013-07-31', 'Medical Hold', 'Rabbit', 'Maine Coon', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (14, 'Pebbles', 79, 'Small', 'Low', '2022-03-29', 'Adopted', 'Cat', 'Golden Retriever', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (15, 'Oreo', 121, 'Large', 'High', '2025-02-23', 'Available', 'Cat', 'Siamese', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (16, 'Sunny', 50, 'Small', 'High', '2005-03-18', 'Fostered', 'Cat', 'Poodle', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (17, 'Pumpkin', 111, 'Small', 'Low', '2009-02-15', 'Fostered', 'Other', 'Golden Retriever', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (18, 'Gizmo', 154, 'Large', 'Medium', '2003-08-16', 'Pending Adoption', 'Other', 'Poodle', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (19, 'Toffee', 188, 'Midsize', 'Medium', '2021-09-09', 'Fostered', 'Rabbit', 'Maine Coon', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (20, 'Honey', 14, 'Large', 'Medium', '2014-12-27', 'Available', 'Other', 'Bengal', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (21, 'Bubbles', 158, 'Small', 'High', '2015-12-21', 'Fostered', 'Cat', 'Bengal', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (22, 'Snickers', 189, 'Midsize', 'Low', '2015-07-30', 'Available', 'Cat', 'Bengal', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (23, 'Cherry', 131, 'Large', 'High', '2018-12-13', 'Adopted', 'Other', 'Beagle', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (24, 'Gizmo', 32, 'Large', 'Medium', '2001-06-01', 'Available', 'Rabbit', 'German Shepherd', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (25, 'Cherry', 52, 'Small', 'Medium', '2002-07-25', 'Pending Adoption', 'Dog', 'Labrador Retriever', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (26, 'Tulip', 126, 'Small', 'High', '2013-04-23', 'Medical Hold', 'Dog', 'Bengal', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (27, 'Peanut', 183, 'Small', 'Low', '2020-05-18', 'Adopted', 'Cat', 'Ragdoll', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (28, 'Pebbles', 194, 'Small', 'Medium', '2020-07-07', 'Available', 'Dog', 'Golden Retriever', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (29, 'Pebbles', 110, 'Small', 'Medium', '2018-10-18', 'Medical Hold', 'Cat', 'Siamese', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (30, 'Snickers', 47, 'Small', 'High', '2016-12-31', 'Adopted', 'Other', 'Persian', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (31, 'Pebbles', 15, 'Small', 'High', '2012-07-22', 'Adopted', 'Cat', 'Beagle', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (32, 'Pebbles', 130, 'Midsize', 'High', '2015-04-13', 'Available', 'Dog', 'Persian', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (33, 'Twinkie', 36, 'Midsize', 'Medium', '2014-05-13', 'Available', 'Rabbit', 'German Shepherd', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (34, 'Pebbles', 177, 'Midsize', 'Medium', '2004-09-15', 'Medical Hold', 'Other', 'German Shepherd', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (35, 'Pebbles', 179, 'Midsize', 'Low', '2016-12-31', 'Available', 'Dog', 'Persian', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (36, 'Ziggy', 112, 'Large', 'Low', '2002-03-04', 'Pending Adoption', 'Other', 'Siamese', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (37, 'Pippin', 86, 'Large', 'High', '2019-06-20', 'Available', 'Dog', 'Siamese', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (38, 'Whiskers', 145, 'Midsize', 'High', '2013-12-25', 'Medical Hold', 'Rabbit', 'Ragdoll', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (39, 'Snickers', 165, 'Large', 'Low', '2015-09-23', 'Medical Hold', 'Other', 'Persian', false);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (40, 'Luna', 14, 'Small', 'High', '2012-06-20', 'Adopted', 'Cat', 'Siamese', true);
insert ignore into animal (animal_id, name, age_months, size, energy_level, intake_date, status, species, breed, flagged) values (40, 'Luna', 14, 'Small', 'High', '2012-06-20', 'Adopted', 'Cat', 'Siamese', true);


insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (1, 'Lisa', 'Johnson', 'ljohnson3@theguardian.com', '194-408-8884', '0301 Onsgard Trail');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (2, 'Brenda', 'Robbie', 'brobbie1@studiopress.com', '139-436-6760', '901 Schlimgen Avenue');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (3, 'Dud', 'Ricciardo', 'dricciardo2@upenn.edu', '953-204-9328', '49584 Memorial Road');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (4, 'Pauly', 'Doogood', 'pdoogood3@shinystat.com', '953-754-8939', '2308 Fairview Court');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (5, 'Velma', 'Ondrak', 'vondrak4@acquirethisname.com', '924-611-8202', '317 Sage Trail');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (6, 'Kylen', 'Kilmurry', 'kkilmurry5@thetimes.co.uk', '217-563-9671', '01302 Westridge Terrace');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (7, 'Jillana', 'Foxton', 'jfoxton6@toplist.cz', '259-753-2658', '13757 Dexter Street');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (8, 'Sophia', 'Fursse', 'sfursse7@etsy.com', '561-922-6964', '53 Dennis Court');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (9, 'Milty', 'Pratt', 'mpratt8@meetup.com', '880-546-6434', '89521 Montana Lane');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (10, 'Grier', 'Giacobazzi', 'ggiacobazzi9@toplist.cz', '338-380-7608', '273 Fisk Place');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (11, 'Janka', 'Gillbe', 'jgillbea@booking.com', '533-643-5281', '1 4th Trail');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (12, 'Finley', 'Vowell', 'fvowellb@wordpress.com', '419-219-5324', '21546 Declaration Circle');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (13, 'Yale', 'Stears', 'ystearsc@merriam-webster.com', '300-274-2402', '5 Magdeline Avenue');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (14, 'Leigha', 'Freeth', 'lfreethd@state.gov', '945-758-4840', '7 Springs Circle');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (15, 'Konstantine', 'Moorcroft', 'kmoorcrofte@microsoft.com', '128-521-5948', '995 Amoth Street');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (16, 'Andras', 'McMorland', 'amcmorlandf@flavors.me', '511-712-5694', '3770 Acker Point');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (17, 'Laurens', 'Paulus', 'lpaulusg@unicef.org', '562-261-5269', '54 Kinsman Road');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (18, 'Sylvan', 'Goulter', 'sgoulterh@shareasale.com', '485-179-7973', '2960 Esker Road');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (19, 'Cassey', 'Crang', 'ccrangi@twitter.com', '866-748-2046', '9 Ludington Street');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (20, 'Jock', 'Spenton', 'jspentonj@guardian.co.uk', '954-373-3784', '960 Merrick Hill');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (21, 'Opalina', 'Belliard', 'obelliardk@delicious.com', '407-300-2952', '7 Bartelt Junction');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (22, 'Coral', 'Bertome', 'cbertomel@live.com', '946-986-2305', '94 Graceland Way');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (23, 'Danny', 'Daftor', 'ddaftorm@imageshack.us', '426-468-8957', '61 Lerdahl Lane');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (24, 'Karlyn', 'Barbisch', 'kbarbischn@yahoo.com', '442-974-8474', '9459 Carioca Place');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (25, 'Courtney', 'Hardson', 'chardsono@opensource.org', '640-214-6090', '70205 Warner Terrace');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (26, 'Tedd', 'Smieton', 'tsmietonp@merriam-webster.com', '158-567-4944', '35341 Loftsgordon Hill');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (27, 'Robinet', 'Chugg', 'rchuggq@redcross.org', '372-415-2188', '133 Mallard Drive');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (28, 'Craig', 'Mityukov', 'cmityukovr@blog.com', '525-513-0028', '918 Lighthouse Bay Road');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (29, 'Sonja', 'Giovanizio', 'sgiovanizios@sciencedaily.com', '134-146-1713', '76 Eagan Court');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (30, 'Forbes', 'Quibell', 'fquibellt@woothemes.com', '751-699-3238', '57510 Hallows Hill');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (31, 'Alasdair', 'London', 'alondonu@sohu.com', '428-684-0177', '46 Eagle Crest Drive');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (32, 'Kassi', 'Orlton', 'korltonv@omniture.com', '443-372-6518', '29348 Forest Run Avenue');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (33, 'Ynes', 'Reolfo', 'yreolfow@e-recht24.de', '582-568-9500', '6 Nova Avenue');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (34, 'Jenilee', 'Paladino', 'jpaladinox@typepad.com', '695-690-6857', '6068 Bluejay Trail');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (35, 'Britni', 'Billington', 'bbillingtony@so-net.ne.jp', '891-841-9630', '8 Huxley Crossing');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (36, 'Bradney', 'Philippeaux', 'bphilippeauxz@4shared.com', '323-461-6501', '5222 Oneill Circle');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (37, 'Isidora', 'Kehri', 'ikehri10@earthlink.net', '622-554-5411', '16261 Gulseth Hill');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (38, 'Lotta', 'Marnane', 'lmarnane11@wsj.com', '757-791-3675', '3835 Florence Parkway');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (39, 'Sibel', 'Lamont', 'slamont12@mapy.cz', '455-348-7719', '687 Beilfuss Court');
insert ignore into adopter (adopter_id, first_name, last_name, email, phone, address) values (40, 'Laina', 'Karchewski', 'lkarchewski13@cornell.edu', '431-333-3384', '26 Garrison Avenue');

insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (1, 'Felic', 'Gilfether', 'fgilfether0@myspace.com', 'hashed_pass_1', '503 Mcbride Alley', '2025-03-28');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (2, 'Ethelda', 'Golby', 'egolby1@behance.net', 'hashed_pass_2', '7863 Summerview Hill', '2025-05-12');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (3, 'Briney', 'Cluet', 'bcluet2@sitemeter.com', 'hashed_pass_3', '31895 Susan Point', '2025-08-25');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (4, 'Murdock', 'Samsonsen', 'msamsonsen3@wisc.edu', 'hashed_pass_4', '97 Luster Way', '2025-03-08');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (5, 'Guilbert', 'Robbel', 'grobbel4@independent.co.uk', 'hashed_pass_5', '7433 Corry Point', '2025-04-17');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (6, 'Ansell', 'Vaune', 'avaune5@gravatar.com', 'hashed_pass_6', '90 Waxwing Pass', '2025-01-18');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (7, 'Anselma', 'Drinkhall', 'adrinkhall6@a8.net', 'hashed_pass_7', '5147 Prairie Rose Point', '2025-02-23');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (8, 'Ameline', 'Annis', 'aannis7@nhs.uk', 'hashed_pass_8', '77199 Arkansas Alley', '2025-12-15');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (9, 'Gates', 'Wrigley', 'gwrigley8@disqus.com', 'hashed_pass_9', '44 Burrows Circle', '2025-02-14');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (10, 'Jaclyn', 'Balogh', 'jbalogh9@cargocollective.com', 'hashed_pass_10', '91 Butternut Parkway', '2025-10-06');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (11, 'Golda', 'Lauga', 'glaugaa@psu.edu', 'hashed_pass_11', '0 Lillian Street', '2025-01-28');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (12, 'Feodora', 'Gooderick', 'fgooderickb@dailymotion.com', 'hashed_pass_12', '42714 Vera Circle', '2025-07-14');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (13, 'Leilah', 'Haresnape', 'lharesnapec@istockphoto.com', 'hashed_pass_13', '207 Bobwhite Alley', '2025-11-09');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (14, 'Elliott', 'Copley', 'ecopleyd@livejournal.com', 'hashed_pass_14', '49 Schmedeman Terrace', '2025-01-28');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (15, 'Teriann', 'Lighterness', 'tlighternesse@1688.com', 'hashed_pass_15', '2306 Lunder Plaza', '2025-10-02');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (16, 'Donovan', 'Rubra', 'drubraf@wordpress.org', 'hashed_pass_16', '92 Sloan Plaza', '2025-09-12');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (17, 'Kizzie', 'Walenta', 'kwalentag@tiny.cc', 'hashed_pass_17', '3745 Mariners Cove Avenue', '2025-05-05');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (18, 'Rouvin', 'Service', 'rserviceh@baidu.com', 'hashed_pass_18', '924 Chinook Avenue', '2025-09-14');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (19, 'Ari', 'Skaife', 'askaifei@tiny.cc', 'hashed_pass_19', '32505 Linden Way', '2025-09-12');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (20, 'Cortie', 'Grinley', 'cgrinleyj@themeforest.net', 'hashed_pass_20', '0 Gateway Court', '2025-04-17');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (21, 'Grace', 'Faustin', 'gfaustink@istockphoto.com', 'hashed_pass_21', '38 Leroy Point', '2025-01-02');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (22, 'Will', 'Ferras', 'wferrasl@wufoo.com', 'hashed_pass_22', '3 Jenna Plaza', '2025-04-15');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (23, 'Sheba', 'Blueman', 'sbluemanm@nhs.uk', 'hashed_pass_23', '7763 Debra Junction', '2025-09-18');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (24, 'Ronnica', 'Stitfall', 'rstitfalln@ycombinator.com', 'hashed_pass_24', '697 8th Junction', '2025-09-03');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (25, 'Ced', 'Maryon', 'cmaryono@businessweek.com', 'hashed_pass_25', '22 Sachs Drive', '2025-10-21');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (26, 'Clarine', 'Chatan', 'cchatanp@npr.org', 'hashed_pass_26', '6387 Hermina Plaza', '2025-02-21');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (27, 'Miller', 'Garrud', 'mgarrudq@jimdo.com', 'hashed_pass_27', '77856 Superior Avenue', '2025-08-11');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (28, 'Dylan', 'Woodlands', 'dwoodlandsr@shutterfly.com', 'hashed_pass_28', '672 Fieldstone Pass', '2025-06-05');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (29, 'Wylma', 'Marages', 'wmaragess@stanford.edu', 'hashed_pass_29', '93392 Buhler Road', '2025-11-12');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (30, 'Tuck', 'Aizikov', 'taizikovt@dion.ne.jp', 'hashed_pass_30', '69066 Valley Edge Park', '2025-05-02');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (31, 'Bone', 'Goodhay', 'bgoodhayu@japanpost.jp', 'hashed_pass_31', '040 Grayhawk Crossing', '2025-07-23');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (32, 'Gerome', 'Benard', 'gbenardv@about.com', 'hashed_pass_32', '44200 Hoffman Way', '2025-05-16');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (33, 'Denny', 'Serginson', 'dserginsonw@sourceforge.net', 'hashed_pass_33', '42 Eagan Place', '2025-11-17');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (34, 'Virgina', 'Ogborn', 'vogbornx@bizjournals.com', 'hashed_pass_34', '89 Debra Way', '2025-07-03');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (35, 'Torrey', 'Northern', 'tnortherny@wikispaces.com', 'hashed_pass_35', '23 Claremont Pass', '2025-03-16');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (36, 'Desiri', 'Anslow', 'danslowz@springer.com', 'hashed_pass_36', '189 Red Cloud Lane', '2025-09-10');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (37, 'Kirbee', 'Grishmanov', 'kgrishmanov10@ustream.tv', 'hashed_pass_37', '59019 Logan Lane', '2025-01-11');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (38, 'Timi', 'Iannini', 'tiannini11@go.com', 'hashed_pass_38', '18 Ruskin Pass', '2025-08-12');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (39, 'Dorolice', 'Etherington', 'detherington12@kickstarter.com', 'hashed_pass_39', '844 Columbus Way', '2025-04-22');
insert ignore into employee (employee_id, first_name, last_name, email, password, address, created_at) values (40, 'Dolley', 'Cheke', 'dcheke13@typepad.com', 'hashed_pass_40', '87288 Kinsman Junction', '2025-05-08');

insert ignore into employee_role (employee_id, role, permissions) values (1, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert ignore into employee_role (employee_id, role, permissions) values (2, 'Analyst', 'view_animals,view_reports');
insert ignore into employee_role (employee_id, role, permissions) values (3, 'Volunteer', 'view_animals');
insert ignore into employee_role (employee_id, role, permissions) values (4, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert ignore into employee_role (employee_id, role, permissions) values (5, 'Admin', 'view_animals,edit_animals,manage_adoptions,view_reports,manage_employees');
insert ignore into employee_role (employee_id, role, permissions) values (6, 'Volunteer', 'view_animals');
insert ignore into employee_role (employee_id, role, permissions) values (7, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert ignore into employee_role (employee_id, role, permissions) values (8, 'Analyst', 'view_animals,view_reports');
insert ignore into employee_role (employee_id, role, permissions) values (9, 'Volunteer', 'view_animals');
insert ignore into employee_role (employee_id, role, permissions) values (10, 'Staff', 'view_animals,edit_animals');
insert ignore into employee_role (employee_id, role, permissions) values (11, 'Admin', 'view_animals,edit_animals,manage_adoptions,view_reports,manage_employees');
insert ignore into employee_role (employee_id, role, permissions) values (12, 'Volunteer', 'view_animals');
insert ignore into employee_role (employee_id, role, permissions) values (13, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert ignore into employee_role (employee_id, role, permissions) values (14, 'Analyst', 'view_animals,view_reports');
insert ignore into employee_role (employee_id, role, permissions) values (15, 'Volunteer', 'view_animals');
insert ignore into employee_role (employee_id, role, permissions) values (16, 'Staff', 'view_animals,edit_animals');
insert ignore into employee_role (employee_id, role, permissions) values (17, 'Admin', 'view_animals,edit_animals,manage_adoptions,view_reports,manage_employees');
insert ignore into employee_role (employee_id, role, permissions) values (18, 'Volunteer', 'view_animals');
insert ignore into employee_role (employee_id, role, permissions) values (19, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert ignore into employee_role (employee_id, role, permissions) values (20, 'Analyst', 'view_animals,view_reports');
insert ignore into employee_role (employee_id, role, permissions) values (21, 'Volunteer', 'view_animals');
insert ignore into employee_role (employee_id, role, permissions) values (22, 'Staff', 'view_animals,edit_animals');
insert ignore into employee_role (employee_id, role, permissions) values (23, 'Admin', 'view_animals,edit_animals,manage_adoptions,view_reports,manage_employees');
insert ignore into employee_role (employee_id, role, permissions) values (24, 'Volunteer', 'view_animals');
insert ignore into employee_role (employee_id, role, permissions) values (25, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert ignore into employee_role (employee_id, role, permissions) values (26, 'Analyst', 'view_animals,view_reports');
insert ignore into employee_role (employee_id, role, permissions) values (27, 'Volunteer', 'view_animals');
insert ignore into employee_role (employee_id, role, permissions) values (28, 'Staff', 'view_animals,edit_animals');
insert ignore into employee_role (employee_id, role, permissions) values (29, 'Admin', 'view_animals,edit_animals,manage_adoptions,view_reports,manage_employees');
insert ignore into employee_role (employee_id, role, permissions) values (30, 'Volunteer', 'view_animals');
insert ignore into employee_role (employee_id, role, permissions) values (31, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert ignore into employee_role (employee_id, role, permissions) values (32, 'Analyst', 'view_animals,view_reports');
insert ignore into employee_role (employee_id, role, permissions) values (33, 'Volunteer', 'view_animals');
insert ignore into employee_role (employee_id, role, permissions) values (34, 'Staff', 'view_animals,edit_animals');
insert ignore into employee_role (employee_id, role, permissions) values (35, 'Admin', 'view_animals,edit_animals,manage_adoptions,view_reports,manage_employees');
insert ignore into employee_role (employee_id, role, permissions) values (36, 'Volunteer', 'view_animals');
insert ignore into employee_role (employee_id, role, permissions) values (37, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert ignore into employee_role (employee_id, role, permissions) values (38, 'Analyst', 'view_animals,view_reports');
insert ignore into employee_role (employee_id, role, permissions) values (39, 'Volunteer', 'view_animals');
insert ignore into employee_role (employee_id, role, permissions) values (40, 'Staff', 'view_animals,edit_animals');

insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (1, 1, 1, 1, 'Updated', 'Medical check-up for dog named Max', 'Feeding schedule for rabbit named Floppy', 'breed', '2006-10-27');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (2, 2, 2, 2, 'Created', 'Medical check-up for dog named Max', 'Adoption of cat named Whiskers', 'breed', '2023-02-08');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (3, 3, 3, 3, 'Status Change', 'Playtime for guinea pig named Peanut', 'Feeding schedule for rabbit named Floppy', 'weight', '2012-10-27');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (4, 4, 4, 4, 'Updated', 'Medical check-up for dog named Max', 'Medical check-up for dog named Max', 'weight', '2025-08-25');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (5, 5, 5, 5, 'Status Change', 'Feeding schedule for rabbit named Floppy', 'Medical check-up for dog named Max', 'weight', '2025-06-20');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (6, 6, 6, 6, 'Deleted', 'Medical check-up for dog named Max', 'Adoption of cat named Whiskers', 'adoption status', '2025-10-05');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (7, 7, 7, 7, 'Status Change', 'Adoption of cat named Whiskers', 'Playtime for guinea pig named Peanut', 'weight', '2025-08-26');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (8, 8, 8, 8, 'Updated', 'Feeding schedule for rabbit named Floppy', 'Feeding schedule for rabbit named Floppy', 'weight', '2025-09-27');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (9, 9, 9, 9, 'Updated', 'Adoption of cat named Whiskers', 'Adoption of cat named Whiskers', 'age', '2025-10-24');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (10, 10, 10, 10, 'Updated', 'Medical check-up for dog named Max', 'Medical check-up for dog named Max', 'breed', '2025-08-13');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (11, 11, 11, 11, 'Updated', 'Adoption of cat named Whiskers', 'Feeding schedule for rabbit named Floppy', 'adoption status', '2025-04-10');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (12, 12, 12, 12, 'Deleted', 'Adoption of cat named Whiskers', 'Medical check-up for dog named Max', 'breed', '2025-09-12');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (13, 13, 13, 13, 'Created', 'Playtime for guinea pig named Peanut', 'Playtime for guinea pig named Peanut', 'breed', '2025-01-29');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (14, 14, 14, 14, 'Created', 'Adoption of cat named Whiskers', 'Feeding schedule for rabbit named Floppy', 'breed', '2025-02-24');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (15, 15, 15, 15, 'Deleted', 'Adoption of cat named Whiskers', 'Playtime for guinea pig named Peanut', 'adoption status', '2025-06-19');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (16, 16, 16, 16, 'Updated', 'Adoption of cat named Whiskers', 'Medical check-up for dog named Max', 'weight', '2025-04-04');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (17, 17, 17, 17, 'Deleted', 'Playtime for guinea pig named Peanut', 'Medical check-up for dog named Max', 'weight', '2025-06-02');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (18, 18, 18, 18, 'Updated', 'Feeding schedule for rabbit named Floppy', 'Playtime for guinea pig named Peanut', 'age', '2025-05-18');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (19, 19, 19, 19, 'Created', 'Medical check-up for dog named Max', 'Playtime for guinea pig named Peanut', 'name', '2025-08-21');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (20, 20, 20, 20, 'Created', 'Medical check-up for dog named Max', 'Adoption of cat named Whiskers', 'age', '2025-10-10');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (21, 21, 21, 21, 'Deleted', 'Feeding schedule for rabbit named Floppy', 'Adoption of cat named Whiskers', 'breed', '2025-07-19');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (22, 22, 22, 22, 'Status Change', 'Medical check-up for dog named Max', 'Feeding schedule for rabbit named Floppy', 'age', '2025-05-07');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (23, 23, 23, 23, 'Updated', 'Playtime for guinea pig named Peanut', 'Feeding schedule for rabbit named Floppy', 'breed', '2025-03-13');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (24, 24, 24, 24, 'Updated', 'Playtime for guinea pig named Peanut', 'Medical check-up for dog named Max', 'adoption status', '2025-05-31');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (25, 25, 25, 25, 'Created', 'Feeding schedule for rabbit named Floppy', 'Adoption of cat named Whiskers', 'breed', '2025-04-22');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (26, 26, 26, 26, 'Created', 'Playtime for guinea pig named Peanut', 'Medical check-up for dog named Max', 'age', '2025-02-27');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (27, 27, 27, 27, 'Status Change', 'Adoption of cat named Whiskers', 'Feeding schedule for rabbit named Floppy', 'adoption status', '2025-02-24');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (28, 28, 28, 28, 'Created', 'Feeding schedule for rabbit named Floppy', 'Adoption of cat named Whiskers', 'name', '2025-10-14');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (29, 29, 29, 29, 'Created', 'Playtime for guinea pig named Peanut', 'Adoption of cat named Whiskers', 'name', '2025-09-07');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (30, 30, 30, 30, 'Deleted', 'Feeding schedule for rabbit named Floppy', 'Playtime for guinea pig named Peanut', 'age', '2025-04-05');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (31, 31, 31, 31, 'Created', 'Playtime for guinea pig named Peanut', 'Playtime for guinea pig named Peanut', 'adoption status', '2025-04-04');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (32, 32, 32, 32, 'Deleted', 'Medical check-up for dog named Max', 'Medical check-up for dog named Max', 'name', '2025-10-12');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (33, 33, 33, 33, 'Status Change', 'Medical check-up for dog named Max', 'Playtime for guinea pig named Peanut', 'weight', '2025-02-03');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (34, 34, 34, 34, 'Status Change', 'Adoption of cat named Whiskers', 'Feeding schedule for rabbit named Floppy', 'weight', '2025-08-24');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (35, 35, 35, 35, 'Updated', 'Medical check-up for dog named Max', 'Playtime for guinea pig named Peanut', 'adoption status', '2025-08-29');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (36, 36, 36, 36, 'Created', 'Feeding schedule for rabbit named Floppy', 'Medical check-up for dog named Max', 'adoption status', '2025-07-09');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (37, 37, 37, 37, 'Updated', 'Playtime for guinea pig named Peanut', 'Medical check-up for dog named Max', 'name', '2025-10-23');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (38, 38, 38, 38, 'Created', 'Feeding schedule for rabbit named Floppy', 'Medical check-up for dog named Max', 'breed', '2025-03-07');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (39, 39, 39, 39, 'Deleted', 'Feeding schedule for rabbit named Floppy', 'Feeding schedule for rabbit named Floppy', 'adoption status', '2025-09-09');
insert ignore into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (40, 40, 40, 40, 'Updated', 'Adoption of cat named Whiskers', 'Medical check-up for dog named Max', 'adoption status', '2025-01-24');

insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (1, 1, 1, 'Completed', 'Loves belly rubs', '2006-05-28', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (2, 2, 2, 'Under Review', 'Needs a yard to run', '2023-08-31', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (3, 3, 3, 'Pending', 'Loves belly rubs', '2012-04-02', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (4, 4, 4, 'Approved', 'Needs a yard to run', '2020-04-26', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (5, 5, 5, 'Pending', 'Shy at first', '2004-05-10', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (6, 6, 6, 'Denied', 'Needs a yard to run', '2011-06-09', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (7, 7, 7, 'Approved', 'House trained', '2022-07-11', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (8, 8, 8, 'Denied', 'Good with kids', '2006-04-24', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (9, 9, 9, 'Pending', 'House trained', '2024-02-01', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (10, 10, 10, 'Under Review', 'House trained', '2016-08-10', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (11, 11, 11, 'Under Review', 'Needs a yard to run', '2024-11-10', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (12, 12, 12, 'Withdrawn', 'House trained', '2008-08-02', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (13, 13, 13, 'Approved', 'Loves belly rubs', '2018-06-03', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (14, 14, 14, 'Approved', 'House trained', '2018-08-11', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (15, 15, 15, 'Completed', 'Loves belly rubs', '2003-02-05', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (16, 16, 16, 'Under Review', 'Shy at first', '2006-07-16', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (17, 17, 17, 'Approved', 'Good with kids', '2005-10-08', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (18, 18, 18, 'Denied', 'House trained', '2000-06-05', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (19, 19, 19, 'Withdrawn', 'Good with kids', '2021-04-28', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (20, 20, 20, 'Withdrawn', 'Loves belly rubs', '2020-03-25', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (21, 21, 21, 'Completed', 'Good with kids', '2006-06-11', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (22, 22, 22, 'Pending', 'Good with kids', '2007-11-15', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (23, 23, 23, 'Approved', 'Good with kids', '2004-10-07', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (24, 24, 24, 'Withdrawn', 'Shy at first', '2024-09-07', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (25, 25, 25, 'Under Review', 'House trained', '2011-06-06', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (26, 26, 26, 'Withdrawn', 'Shy at first', '2022-03-11', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (27, 27, 27, 'Approved', 'Shy at first', '2016-03-23', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (28, 28, 28, 'Approved', 'Shy at first', '2019-01-07', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (29, 29, 29, 'Completed', 'Needs a yard to run', '2004-03-29', '2025-04-15');
insert ignore into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (30, 30, 30, 'Pending', 'Good with kids', '2003-02-28', '2025-04-15');

insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (1, 'Vomiting after meals', 'Jane Smith', '2012-10-13', 'Medication', 1);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (2, 'Vomiting after meals', 'Michael Johnson', '2013-03-15', 'Checkup', 2);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (3, 'Limping on left hind leg', 'Robert Brown', '2008-04-02', 'Medication', 3);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (4, 'Heart rate normal', 'Emily Davis', '2012-04-18', 'Checkup', 4);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (5, 'Heart rate normal', 'Emily Davis', '2014-12-17', 'Vaccination', 5);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (6, 'Vomiting after meals', 'Michael Johnson', '2011-06-22', 'Medication', 6);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (7, 'Loss of appetite', 'Michael Johnson', '2018-01-26', 'Surgery', 7);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (8, 'Sneezing frequently', 'Michael Johnson', '2019-05-19', 'Treatment', 8);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (9, 'Sneezing frequently', 'Emily Davis', '2018-08-08', 'Vaccination', 9);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (10, 'Heart rate normal', 'Robert Brown', '2025-11-25', 'Spray/Neuter', 10);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (11, 'Vomiting after meals', 'Jane Smith', '2007-02-11', 'Spray/Neuter', 11);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (12, 'Sneezing frequently', 'John Doe', '2022-08-24', 'Checkup', 12);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (13, 'Limping on left hind leg', 'Robert Brown', '2005-02-18', 'Spray/Neuter', 13);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (14, 'Vomiting after meals', 'Michael Johnson', '2007-01-19', 'Surgery', 14);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (15, 'Heart rate normal', 'Michael Johnson', '2001-09-24', 'Vaccination', 15);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (16, 'Limping on left hind leg', 'John Doe', '2000-11-30', 'Treatment', 16);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (17, 'Limping on left hind leg', 'John Doe', '2024-03-30', 'Treatment', 17);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (18, 'Vomiting after meals', 'John Doe', '2008-12-14', 'Treatment', 18);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (19, 'Limping on left hind leg', 'Jane Smith', '2024-01-18', 'Checkup', 19);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (20, 'Loss of appetite', 'Jane Smith', '2016-01-09', 'Vaccination', 20);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (21, 'Vomiting after meals', 'Michael Johnson', '2005-12-18', 'Surgery', 21);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (22, 'Vomiting after meals', 'Jane Smith', '2001-11-24', 'Spray/Neuter', 22);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (23, 'Limping on left hind leg', 'Emily Davis', '2020-02-24', 'Surgery', 23);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (24, 'Loss of appetite', 'John Doe', '2024-11-18', 'Vaccination', 24);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (25, 'Loss of appetite', 'Michael Johnson', '2005-02-18', 'Medication', 25);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (26, 'Loss of appetite', 'Emily Davis', '2002-03-23', 'Surgery', 26);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (27, 'Heart rate normal', 'Robert Brown', '2000-10-13', 'Surgery', 27);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (28, 'Vomiting after meals', 'Emily Davis', '2018-03-20', 'Vaccination', 28);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (29, 'Sneezing frequently', 'Robert Brown', '2007-07-18', 'Vaccination', 29);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (30, 'Vomiting after meals', 'Jane Smith', '2005-11-21', 'Vaccination', 30);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (31, 'Heart rate normal', 'Jane Smith', '2006-10-03', 'Surgery', 31);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (32, 'Vomiting after meals', 'Robert Brown', '2006-01-09', 'Vaccination', 32);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (33, 'Loss of appetite', 'Jane Smith', '2020-11-09', 'Surgery', 33);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (34, 'Limping on left hind leg', 'Michael Johnson', '2023-10-20', 'Checkup', 34);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (35, 'Vomiting after meals', 'Michael Johnson', '2001-08-12', 'Medication', 35);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (36, 'Heart rate normal', 'John Doe', '2010-11-18', 'Treatment', 36);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (37, 'Loss of appetite', 'John Doe', '2008-03-06', 'Surgery', 37);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (38, 'Heart rate normal', 'Michael Johnson', '2020-01-16', 'Medication', 38);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (39, 'Heart rate normal', 'Michael Johnson', '2005-03-03', 'Surgery', 39);
insert ignore into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (40, 'Heart rate normal', 'Robert Brown', '2015-12-19', 'Treatment', 40);

insert ignore into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (1, 1, '2007-01-26', '2011-06-21', 274, 75.15, 197.89);
insert ignore into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (2, 2, '2010-07-12', '2016-05-13', 24, 213.74, 118.82);
insert ignore into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (3, 3, '2025-12-30', '2008-02-21', 489, 270.38, 158.14);
insert ignore into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (4, 4, '2019-01-25', '2023-04-23', 603, 123.47, 125.44);
insert ignore into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (5, 5, '2001-06-02', '2009-01-29', 696, 83.32, 289.43);
insert ignore into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (6, 6, '2025-05-03', '2012-08-10', 72, 110.02, 56.61);
insert ignore into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (7, 7, '2001-02-05', '2017-10-13', 908, 345.4, 342.61);
insert ignore into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (8, 8, '2012-11-04', '2012-12-20', 102, 23.21, 159.35);
insert ignore into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (9, 9, '2010-05-09', '2022-04-25', 978, 197.81, 18.45);
insert ignore into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (10, 10, '2023-08-09', '2024-11-17', 918, 155.37, 162.31);

insert ignore into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (1, 'Q1 Adoptions', false, 'PDF', 'Total Adopted', '2007-01-01', '2007-03-31');
insert ignore into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (2, 'Mid-Year Review', false, 'CSV', 'Species Breakdown', '2010-07-01', '2010-09-30');
insert ignore into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (3, 'Year End 2025', false, 'PDF', 'Total Adopted,Average Days to Adopt', '2025-01-01', '2025-12-31');
insert ignore into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (4, 'Q1 2019', false, 'Excel', 'Average Length of Stay', '2019-01-01', '2019-03-31');
insert ignore into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (5, 'Archived 2001', true, 'PDF', 'Total Adopted', '2001-01-01', '2001-12-31');
insert ignore into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (6, 'Spring 2025', false, 'CSV', 'Intake Count', '2025-03-01', '2025-05-31');
insert ignore into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (7, 'Early 2001', true, 'PDF', 'Species Breakdown', '2001-01-01', '2001-06-30');
insert ignore into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (8, 'Fall 2012', false, 'Excel', 'Total Adopted,Average Length of Stay', '2012-09-01', '2012-11-30');
insert ignore into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (9, 'Spring 2010', false, 'CSV', 'Average Days to Adopt', '2010-03-01', '2010-05-31');
insert ignore into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (10, 'Summer 2023', false, 'PDF', 'Total Adopted,Species Breakdown', '2023-06-01', '2023-08-31');

insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (1, 1, 1, '2003-09-05', 'Adopted', 618, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (2, 2, 2, '2002-09-05', 'Adopted', 900, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (3, 3, 3, '2016-11-01', 'Returned', 716, true);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (4, 4, 4, '2019-12-28', 'Fostered', 477, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (5, 5, 5, '2004-03-19', 'Fostered', 685, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (6, 6, 6, '2006-06-23', 'Returned', 900, true);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (7, 7, 7, '2000-04-04', 'Returned', 158, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (8, 8, 8, '2007-01-18', 'Adopted', 11, true);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (9, 9, 9, '2014-03-14', 'Returned', 378, true);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (10, 10, 10, '2006-11-21', 'Adopted', 491, true);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (11, 11, 1, '2024-08-05', 'Fostered', 642, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (12, 12, 2, '2002-03-30', 'Fostered', 286, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (13, 13, 3, '2006-05-08', 'Adopted', 277, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (14, 14, 4, '2004-04-07', 'Fostered', 22, true);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (15, 15, 5, '2021-06-13', 'Adopted', 504, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (16, 16, 6, '2003-12-17', 'Returned', 826, true);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (17, 17, 7, '2025-09-02', 'Adopted', 304, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (18, 18, 8, '2020-08-28', 'Adopted', 556, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (19, 19, 9, '2000-02-03', 'Adopted', 549, true);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (20, 20, 10, '2018-10-20', 'Fostered', 682, true);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (21, 21, 1, '2003-11-17', 'Returned', 17, true);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (22, 22, 2, '2003-07-19', 'Adopted', 527, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (23, 23, 3, '2017-02-09', 'Fostered', 908, true);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (24, 24, 4, '2003-12-26', 'Fostered', 379, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (25, 25, 5, '2002-05-15', 'Adopted', 279, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (26, 26, 6, '2001-01-28', 'Adopted', 37, true);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (27, 27, 7, '2012-12-19', 'Returned', 861, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (28, 28, 8, '2003-08-13', 'Returned', 209, true);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (29, 29, 9, '2014-02-20', 'Adopted', 811, false);
insert ignore into adoption (adoption_id, application_id, report_id, adoption_date, outcome, days_to_adopt, return_flag) values (30, 30, 10, '2024-04-29', 'Fostered', 805, true);

insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (1, 4, 17, 'Completed', '2011-12-26 10:00:00', 'pellentesque ultrices');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (2, 21, 8, 'No Show', '2013-07-20 14:00:00', null);
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (3, 38, 40, 'Cancelled', '2004-02-15 09:00:00', 'ipsum primis in faucibus');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (4, 35, 17, 'Cancelled', '2012-07-04 11:00:00', 'mauris lacinia sapien');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (5, 38, 20, 'Cancelled', '2023-12-14 13:00:00', null);
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (6, 39, 26, 'Scheduled', '2026-11-13 10:00:00', 'nunc commodo placerat');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (7, 4, 5, 'No Show', '2012-10-08 15:00:00', 'quis turpis sed ante');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (8, 9, 23, 'Scheduled', '2026-07-31 09:00:00', null);
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (9, 23, 36, 'Scheduled', '2026-08-27 14:00:00', 'risus praesent lectus');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (10, 18, 38, 'No Show', '2007-09-05 10:00:00', 'in ante vestibulum');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (11, 26, 20, 'No Show', '2012-01-06 11:00:00', null);
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (12, 26, 31, 'No Show', '2021-11-09 13:00:00', null);
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (13, 23, 15, 'Cancelled', '2023-02-09 10:00:00', 'feugiat et eros');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (14, 14, 17, 'No Show', '2021-12-30 14:00:00', 'pretium iaculis diam');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (15, 6, 10, 'Scheduled', '2026-12-23 09:00:00', null);
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (16, 26, 38, 'Scheduled', '2026-05-31 11:00:00', null);
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (17, 27, 38, 'Scheduled', '2026-06-15 10:00:00', 'potenti nullam porttitor');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (18, 11, 2, 'Completed', '2000-01-23 13:00:00', 'id mauris vulputate');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (19, 14, 37, 'Scheduled', '2026-01-17 09:00:00', 'sapien placerat ante');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (20, 4, 13, 'Cancelled', '2011-03-12 14:00:00', 'penatibus et magnis');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (21, 31, 17, 'Cancelled', '2005-12-12 10:00:00', 'ultrices vel augue');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (22, 1, 26, 'No Show', '2017-11-25 11:00:00', 'nisi at nibh');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (23, 30, 37, 'No Show', '2010-06-05 13:00:00', 'et magnis dis parturient');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (24, 1, 25, 'Completed', '2023-07-29 10:00:00', 'consequat lectus in est');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (25, 24, 5, 'Completed', '2011-08-19 14:00:00', null);
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (26, 30, 23, 'Cancelled', '2010-11-06 09:00:00', 'sit amet consectetuer');
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (27, 31, 35, 'Completed', '2006-12-25 11:00:00', null);
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (28, 20, 36, 'Scheduled', '2026-12-10 10:00:00', null);
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (29, 37, 13, 'Scheduled', '2026-06-01 14:00:00', null);
insert ignore into meet_appointment (appointment_id, adopter_id, animal_id, status, scheduled_for, notes) values (30, 18, 11, 'Completed', '2025-08-11 09:00:00', null);

insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (1, 13, 30, 6, false, 'In quis justo. Maecenas rhoncus aliquam lacus. Morbi quis tortor id nulla ultrices aliquet.', '2016-09-30 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (2, 32, 20, 9, false, 'Integer tincidunt ante vel ipsum. Praesent blandit lacinia erat.', '2006-03-22 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (3, 17, 9, 10, true, 'Morbi non lectus. Aliquam sit amet diam in magna bibendum imperdiet.', '2019-08-18 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (4, 32, 4, 2, true, 'Pellentesque at nulla. Suspendisse potenti. Cras in purus eu magna vulputate luctus.', '2025-01-23 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (5, 16, 38, 1, true, 'Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.', '2001-04-19 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (6, 5, 29, 6, false, 'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Proin risus.', '2009-09-20 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (7, 10, 15, 8, true, 'In hac habitasse platea dictumst. Morbi vestibulum, velit id pretium iaculis.', '2004-03-22 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (8, 8, 5, 4, true, 'Proin eu mi. Nulla ac enim. In tempor, turpis nec euismod scelerisque.', '2001-10-16 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (9, 38, 24, 4, false, 'Aliquam quis turpis eget elit sodales scelerisque. Mauris sit amet eros.', '2019-11-30 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (10, 16, 19, 3, false, 'Fusce posuere felis sed lacus. Morbi sem mauris, laoreet ut.', '2014-12-02 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (11, 11, 16, 7, true, 'Fusce consequat. Nulla nisl. Nunc nisl.', '2020-02-24 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (12, 36, 3, 8, true, 'In congue. Etiam justo. Etiam pretium iaculis justo.', '2024-07-22 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (13, 36, 11, 4, false, 'Aenean lectus. Pellentesque eget nunc. Donec quis orci eget orci vehicula condimentum.', '2003-10-31 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (14, 39, 5, 2, false, 'Praesent blandit. Nam nulla. Integer pede justo, lacinia eget.', '2009-09-19 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (15, 23, 37, 6, false, 'Duis aliquam convallis nunc. Proin at turpis a pede posuere nonummy.', '2001-12-01 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (16, 32, 10, 5, true, 'Nam ultrices, libero non mattis pulvinar, nulla pede ullamcorper augue.', '2016-04-13 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (17, 38, 26, 8, false, 'In quis justo. Maecenas rhoncus aliquam lacus. Morbi quis tortor id nulla ultrices aliquet.', '2004-12-05 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (18, 18, 28, 8, true, 'Phasellus sit amet erat. Nulla tempus. Vivamus in felis eu sapien cursus vestibulum.', '2011-03-05 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (19, 16, 34, 6, false, 'In quis justo. Maecenas rhoncus aliquam lacus.', '2025-08-10 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (20, 3, 35, 3, true, 'Morbi non lectus. Aliquam sit amet diam in magna bibendum imperdiet.', '2017-11-10 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (21, 6, 34, 3, true, 'Phasellus sit amet erat. Nulla tempus. Vivamus in felis eu sapien cursus vestibulum.', '2015-04-24 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (22, 6, 34, 7, true, 'In hac habitasse platea dictumst. Morbi vestibulum, velit id pretium iaculis.', '2002-12-08 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (23, 7, 33, 7, true, 'Cras mi pede, malesuada in, imperdiet et, commodo vulputate, justo.', '2010-10-20 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (24, 40, 30, 4, true, 'In congue. Etiam justo. Etiam pretium iaculis justo.', '2004-09-22 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (25, 19, 9, 10, true, 'Nam ultrices, libero non mattis pulvinar, nulla pede ullamcorper augue.', '2008-05-14 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (26, 4, 12, 5, true, 'In sagittis dui vel nisl. Duis ac nibh. Fusce lacus purus, aliquet at.', '2018-04-12 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (27, 38, 25, 8, true, 'Cras non velit nec nisi vulputate nonummy. Maecenas tincidunt lacus at velit.', '2023-01-19 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (28, 23, 38, 7, true, 'Pellentesque at nulla. Suspendisse potenti. Cras in purus eu magna vulputate luctus.', '2017-08-16 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (29, 30, 25, 10, true, 'Duis aliquam convallis nunc. Proin at turpis a pede posuere nonummy.', '2009-06-03 10:00:00');
insert ignore into success_story (story_id, adopter_id, animal_id, rating, is_reviewed, content, posted_at) values (30, 14, 9, 2, true, 'Aliquam quis turpis eget elit sodales scelerisque. Mauris sit amet eros.', '2012-05-25 10:00:00');

insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (1, 40, 'Low', 'Large', 'Rabbit', 'Baby', '2022-11-29');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (2, 3, 'Medium', 'Small', 'Rabbit', 'Baby', '2025-09-25');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (3, 11, 'No Preference', 'Large', 'Dog', 'No Preference', '2023-05-09');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (4, 31, 'Medium', 'No Preference', 'No Preference', 'Baby', '2021-02-13');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (5, 22, 'Medium', 'Large', 'Dog', 'Baby', '2020-02-01');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (6, 16, 'Medium', 'Midsize', 'Rabbit', 'Senior', '2023-05-15');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (7, 12, 'No Preference', 'No Preference', 'No Preference', 'Senior', '2023-04-27');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (8, 8, 'Medium', 'Small', 'Rabbit', 'Baby', '2020-12-18');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (9, 13, 'Low', 'Midsize', 'Rabbit', 'Senior', '2020-04-25');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (10, 38, 'Medium', 'No Preference', 'Rabbit', 'Adult', '2023-10-19');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (11, 23, 'No Preference', 'Small', 'No Preference', 'No Preference', '2023-11-07');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (12, 16, 'Medium', 'Small', 'Cat', 'Senior', '2022-06-10');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (13, 5, 'No Preference', 'Large', 'Dog', 'No Preference', '2022-08-14');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (14, 28, 'Medium', 'Midsize', 'Cat', 'Baby', '2025-09-13');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (15, 5, 'No Preference', 'Large', 'Dog', 'No Preference', '2024-01-22');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (16, 34, 'High', 'No Preference', 'Dog', 'No Preference', '2023-07-17');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (17, 1, 'Medium', 'Large', 'Cat', 'No Preference', '2025-01-10');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (18, 5, 'Low', 'Small', 'Cat', 'Baby', '2022-05-18');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (19, 11, 'High', 'Small', 'Rabbit', 'Adult', '2024-07-04');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (20, 31, 'High', 'Large', 'No Preference', 'No Preference', '2022-06-19');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (21, 22, 'No Preference', 'Small', 'Rabbit', 'Adult', '2022-08-20');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (22, 36, 'Low', 'Small', 'Dog', 'Baby', '2020-10-06');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (23, 31, 'Medium', 'Large', 'Rabbit', 'Baby', '2022-07-10');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (24, 21, 'Low', 'Small', 'Cat', 'No Preference', '2025-08-23');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (25, 28, 'No Preference', 'Large', 'No Preference', 'Baby', '2023-09-22');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (26, 35, 'No Preference', 'Small', 'No Preference', 'Adult', '2025-11-10');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (27, 28, 'High', 'No Preference', 'No Preference', 'Baby', '2021-03-08');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (28, 16, 'No Preference', 'Large', 'No Preference', 'Adult', '2023-02-21');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (29, 39, 'High', 'Large', 'Rabbit', 'Adult', '2021-09-07');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (30, 25, 'High', 'Large', 'Dog', 'No Preference', '2022-02-15');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (31, 39, 'Medium', 'Midsize', 'No Preference', 'No Preference', '2021-01-11');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (32, 28, 'High', 'Midsize', 'No Preference', 'Senior', '2021-06-09');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (33, 4, 'No Preference', 'Midsize', 'Cat', 'Senior', '2022-06-17');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (34, 22, 'No Preference', 'No Preference', 'Cat', 'Adult', '2020-09-07');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (35, 2, 'High', 'Large', 'Rabbit', 'Senior', '2024-11-01');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (36, 35, 'Medium', 'Midsize', 'No Preference', 'Senior', '2022-01-25');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (37, 40, 'No Preference', 'Small', 'Dog', 'Senior', '2020-10-01');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (38, 7, 'Low', 'No Preference', 'Dog', 'Adult', '2024-11-01');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (39, 18, 'Medium', 'Midsize', 'Dog', 'Adult', '2025-05-17');
insert ignore into compatibility_quiz (quiz_id, adopter_id, energy_pref, size_pref, species_pref, age_pref, date_taken) values (40, 36, 'Medium', 'Large', 'No Preference', 'Adult', '2023-10-30');

insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (1, 21, 9, 69);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (2, 4, 7, 16);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (3, 40, 39, 72);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (4, 12, 3, 37);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (5, 24, 10, 38);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (6, 24, 7, 63);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (7, 37, 2, 61);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (8, 31, 36, 13);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (9, 27, 26, 2);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (10, 37, 31, 76);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (11, 6, 29, 37);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (12, 18, 32, 90);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (13, 20, 26, 26);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (14, 6, 15, 30);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (15, 37, 11, 12);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (16, 4, 39, 44);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (17, 39, 33, 47);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (18, 35, 35, 74);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (19, 11, 3, 47);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (20, 32, 16, 55);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (21, 7, 3, 99);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (22, 23, 5, 29);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (23, 38, 4, 64);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (24, 21, 36, 47);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (25, 31, 7, 2);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (26, 1 1, 22, 81);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (27, 1, 18, 11);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (28, 20, 23, 43);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (29, 18, 17, 50);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (30, 25, 10, 51);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (31, 27, 37, 81);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (32, 14, 3, 13);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (33, 35, 38, 45);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (34, 1, 19, 54);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (35, 7, 36, 44);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (36, 15, 5, 87);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (37, 40, 3, 11);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (38, 29, 35, 55);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (39, 7, 21, 94);
insert ignore into quiz_rec (rec_id, quiz_id, animal_id, compatibility_score) values (40, 28, 16, 59);

insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (1, 24, 9, 'Under observation for behavior', 'shy at first but warms up quickly', '2004-06-06', '2018-06-19', 'Foster Unable to Continue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (2, 32, 14, 'Normal check-up completed', 'energetic and playful', '2011-11-05', '2023-03-26', 'Other');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (3, 12, 12, 'Needs vaccination', 'calm and gentle demeanor', '2003-09-22', '2017-05-31', 'Foster Unable to Continue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (4, 34, 10, 'Recovering from surgery', 'energetic and playful', '2005-12-24', '2019-01-05', 'End of Foster Period');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (5, 3, 39, 'Normal check-up completed', 'plays well with other animals', '2000-06-20', '2021-05-11', 'Other');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (6, 6, 25, 'Recovering from surgery', 'shy at first but warms up quickly', '2000-01-14', '2022-06-11', 'Foster Unable to Continue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (7, 31, 31, 'Needs vaccination', 'energetic and playful', '2005-01-12', '2022-12-20', 'Behavioral Issue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (8, 9, 17, 'Requires special diet', 'calm and gentle demeanor', '2000-12-22', '2024-11-13', 'Foster Unable to Continue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (9, 9, 11, 'Needs vaccination', 'plays well with other animals', '2013-02-01', '2018-09-14', 'Other');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (10, 29, 12, 'Normal check-up completed', 'shy at first but warms up quickly', '2008-03-15', '2024-11-01', 'Adoption Ready');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (11, 1, 8, 'Needs vaccination', 'plays well with other animals', '2006-03-13', '2025-03-10', 'Medical Concern');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (12, 15, 24, 'Requires special diet', 'friendly towards humans', '2006-12-06', '2024-01-15', 'Adoption Ready');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (13, 23, 30, 'Normal check-up completed', 'shy at first but warms up quickly', '2015-05-05', '2025-01-04', 'Medical Concern');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (14, 32, 33, 'Requires special diet', 'shy at first but warms up quickly', '2007-05-15', '2022-04-17', 'Other');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (15, 11, 40, 'Recovering from surgery', 'friendly towards humans', '2011-07-24', '2023-05-30', 'Behavioral Issue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (16, 21, 10, 'Needs vaccination', 'energetic and playful', '2014-10-01', '2018-09-04', 'End of Foster Period');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (17, 17, 25, 'Needs vaccination', 'energetic and playful', '2015-02-25', '2024-03-26', 'End of Foster Period');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (18, 17, 13, 'Needs vaccination', 'energetic and playful', '2015-03-03', '2019-12-29', 'Adoption Ready');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (19, 12, 19, 'Needs vaccination', 'shy at first but warms up quickly', '2006-10-22', '2025-11-23', 'Behavioral Issue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (20, 6, 30, 'Recovering from surgery', 'shy at first but warms up quickly', '2003-06-25', '2024-10-12', 'Other');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (21, 37, 23, 'Recovering from surgery', 'calm and gentle demeanor', '2000-12-08', '2017-05-22', 'Adoption Ready');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (22, 4, 5, 'Recovering from surgery', 'energetic and playful', '2000-11-20', '2024-07-13', 'Other');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (23, 10, 14, 'Requires special diet', 'shy at first but warms up quickly', '2003-05-20', '2024-11-19', 'End of Foster Period');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (24, 20, 4, 'Needs vaccination', 'energetic and playful', '2015-07-13', '2024-06-17', 'Behavioral Issue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (25, 1, 32, 'Requires special diet', 'friendly towards humans', '2002-02-21', '2016-02-24', 'Medical Concern');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (26, 24, 37, 'Needs vaccination', 'energetic and playful', '2002-11-14', '2019-07-20', 'Adoption Ready');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (27, 33, 29, 'Under observation for behavior', 'shy at first but warms up quickly', '2011-06-13', '2025-04-17', 'Foster Unable to Continue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (28, 29, 6, 'Under observation for behavior', 'calm and gentle demeanor', '2005-05-26', '2020-04-15', 'Adoption Ready');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (29, 29, 27, 'Recovering from surgery', 'plays well with other animals', '2006-05-04', '2023-01-02', 'Behavioral Issue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (30, 34, 27, 'Normal check-up completed', 'calm and gentle demeanor', '2014-05-15', '2024-10-11', 'Other');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (31, 9, 36, 'Recovering from surgery', 'shy at first but warms up quickly', '2007-10-10', '2024-06-09', 'Adoption Ready');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (32, 23, 40, 'Recovering from surgery', 'energetic and playful', '2012-09-30', '2025-01-28', 'Other');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (33, 22, 1, 'Requires special diet', 'friendly towards humans', '2008-06-07', '2017-09-06', 'End of Foster Period');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (34, 16, 13, 'Requires special diet', 'shy at first but warms up quickly', '2002-07-26', '2017-04-26', 'Foster Unable to Continue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (35, 19, 8, 'Recovering from surgery', 'calm and gentle demeanor', '2012-12-21', '2021-07-07', 'Foster Unable to Continue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (36, 12, 13, 'Needs vaccination', 'energetic and playful', '2004-07-27', '2023-04-20', 'Medical Concern');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (37, 11, 34, 'Under observation for behavior', 'plays well with other animals', '2011-05-17', '2025-02-24', 'Behavioral Issue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (38, 10, 11, 'Normal check-up completed', 'plays well with other animals', '2013-07-07', '2023-05-05', 'Foster Unable to Continue');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (39, 16, 32, 'Requires special diet', 'calm and gentle demeanor', '2006-06-21', '2017-10-13', 'Medical Concern');
insert ignore into foster_placement (placement_id, adopter_id, animal_id, health_notes, behavior_notes, start_date, end_date, return_reason) values (40, 2, 32, 'Under observation for behavior', 'friendly towards humans', '2001-01-23', '2024-08-18', 'Medical Concern');