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
    animal_id   INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(50),
    age_months  INT,
    intake_date DATE,
    status      ENUM('Available', 'Adopted', 'Pending Adoption', 'Fostered', 'Medical Hold')
                NOT NULL DEFAULT 'Available',
    species     ENUM('Dog', 'Cat', 'Rabbit', 'Other') NOT NULL,
    breed       VARCHAR(100),
    flagged     BOOLEAN NOT NULL DEFAULT FALSE,
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
    activity_level   INT NOT NULL CHECK (activity_level BETWEEN 1 AND 10),
    energy_pref      ENUM('Low', 'Medium', 'High'),
    size_pref        ENUM('Small', 'Midsize', 'Large'),
    living_situation ENUM('Apartment', 'House', 'Other'),
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
    compatibility_score INT NOT NULL CHECK (compatibility_score BETWEEN 1 AND 100),
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

insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (1, 'Two-toed tree sloth', 224, '2010-12-22', 'Medical Hold', 'Rabbit', 'Siamese Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (2, 'Lion, steller''s sea', 125, '2004-11-05', 'Fostered', 'Cat', 'Golden Retriever', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (3, 'Salmon, sockeye', 108, '2018-05-08', 'Adopted', 'Rabbit', 'Persian Cat', true);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (4, 'Lemur, lesser mouse', 151, '2010-12-13', 'Adopted', 'Other', 'Golden Retriever', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (5, 'Booby, blue-faced', 92, '2003-06-17', 'Adopted', 'Cat', 'Golden Retriever', true);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (6, 'Blackbird, red-winged', 50, '2018-10-22', 'Pending Adoption', 'Other', 'Persian Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (7, 'Lesser masked weaver', 184, '2003-10-31', 'Pending Adoption', 'Cat', 'Persian Cat', true);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (8, 'Heron, goliath', 169, '2009-12-19', 'Adopted', 'Other', 'Siamese Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (9, 'Shark, blue', 114, '2014-11-05', 'Adopted', 'Dog', 'Siamese Cat', true);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (10, 'Striped hyena', 219, '2000-03-18', 'Available', 'Rabbit', 'Golden Retriever', true);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (11, 'African bush squirrel', 236, '2011-09-14', 'Pending Adoption', 'Other', 'German Shepherd', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (12, 'Ferret, black-footed', 202, '2011-09-23', 'Medical Hold', 'Rabbit', 'Labrador Retriever', true);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (13, 'Cape fox', 72, '2006-04-25', 'Medical Hold', 'Rabbit', 'German Shepherd', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (14, 'Rhea, common', 157, '2014-04-13', 'Medical Hold', 'Dog', 'Labrador Retriever', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (15, 'African polecat', 236, '2009-01-28', 'Available', 'Rabbit', 'German Shepherd', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (16, 'Zorro, common', 181, '2021-12-05', 'Available', 'Dog', 'Labrador Retriever', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (17, 'Wallaby, whip-tailed', 167, '2004-04-25', 'Adopted', 'Dog', 'Labrador Retriever', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (18, 'Pintail, bahama', 160, '2006-01-21', 'Fostered', 'Other', 'German Shepherd', true);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (19, 'Brindled gnu', 118, '2003-01-25', 'Available', 'Rabbit', 'Persian Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (20, 'White-rumped vulture', 118, '2011-07-14', 'Pending Adoption', 'Dog', 'Persian Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (21, 'Long-nosed bandicoot', 93, '2017-12-03', 'Adopted', 'Cat', 'Labrador Retriever', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (22, 'Lizard, blue-tongued', 11, '2012-01-08', 'Adopted', 'Dog', 'Siamese Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (23, 'Spotted deer', 57, '2008-12-18', 'Pending Adoption', 'Rabbit', 'Labrador Retriever', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (24, 'Dove, mourning collared', 139, '2004-12-21', 'Adopted', 'Dog', 'Persian Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (25, 'Snake, green vine', 112, '2011-02-05', 'Available', 'Cat', 'Persian Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (26, 'Shelduck, european', 240, '2008-09-10', 'Pending Adoption', 'Dog', 'Persian Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (27, 'Polecat, african', 84, '2005-02-15', 'Available', 'Dog', 'Labrador Retriever', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (28, 'Baleen whale', 209, '2006-03-10', 'Available', 'Other', 'German Shepherd', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (29, 'African fish eagle', 59, '2021-08-18', 'Pending Adoption', 'Rabbit', 'Siamese Cat', true);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (30, 'African clawless otter', 154, '2012-10-23', 'Fostered', 'Rabbit', 'German Shepherd', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (31, 'Dog, bush', 192, '2002-04-17', 'Available', 'Rabbit', 'Persian Cat', true);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (32, 'Goose, andean', 16, '2021-01-09', 'Fostered', 'Cat', 'Siamese Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (33, 'Heron, gray', 165, '2018-12-30', 'Fostered', 'Rabbit', 'Persian Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (34, 'Beaver, north american', 182, '2014-05-18', 'Pending Adoption', 'Other', 'German Shepherd', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (35, 'Goliath heron', 206, '2018-01-03', 'Fostered', 'Other', 'Siamese Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (36, 'Waxbill, violet-eared', 110, '2019-02-10', 'Adopted', 'Rabbit', 'Siamese Cat', true);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (37, 'Sage grouse', 64, '2020-07-02', 'Pending Adoption', 'Cat', 'Siamese Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (38, 'Sloth, pale-throated three-toed', 144, '2008-02-28', 'Fostered', 'Dog', 'Persian Cat', false);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (39, 'Vine snake (unidentified)', 136, '2013-09-07', 'Fostered', 'Cat', 'Persian Cat', true);
insert into animal (animal_id, name, age_months, intake_date, status, species , breed, flagged) values (40, 'Malleefowl', 225, '2017-12-27', 'Fostered', 'Rabbit', 'Siamese Cat', false);

insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (1, 'Lelah', 'Knath', 'lknath0@theguardian.com', '194-408-8884', '0301 Onsgard Trail');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (2, 'Brenda', 'Robbie', 'brobbie1@studiopress.com', '139-436-6760', '901 Schlimgen Avenue');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (3, 'Dud', 'Ricciardo', 'dricciardo2@upenn.edu', '953-204-9328', '49584 Memorial Road');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (4, 'Pauly', 'Doogood', 'pdoogood3@shinystat.com', '953-754-8939', '2308 Fairview Court');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (5, 'Velma', 'Ondrak', 'vondrak4@acquirethisname.com', '924-611-8202', '317 Sage Trail');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (6, 'Kylen', 'Kilmurry', 'kkilmurry5@thetimes.co.uk', '217-563-9671', '01302 Westridge Terrace');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (7, 'Jillana', 'Foxton', 'jfoxton6@toplist.cz', '259-753-2658', '13757 Dexter Street');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (8, 'Sophia', 'Fursse', 'sfursse7@etsy.com', '561-922-6964', '53 Dennis Court');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (9, 'Milty', 'Pratt', 'mpratt8@meetup.com', '880-546-6434', '89521 Montana Lane');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (10, 'Grier', 'Giacobazzi', 'ggiacobazzi9@toplist.cz', '338-380-7608', '273 Fisk Place');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (11, 'Janka', 'Gillbe', 'jgillbea@booking.com', '533-643-5281', '1 4th Trail');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (12, 'Finley', 'Vowell', 'fvowellb@wordpress.com', '419-219-5324', '21546 Declaration Circle');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (13, 'Yale', 'Stears', 'ystearsc@merriam-webster.com', '300-274-2402', '5 Magdeline Avenue');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (14, 'Leigha', 'Freeth', 'lfreethd@state.gov', '945-758-4840', '7 Springs Circle');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (15, 'Konstantine', 'Moorcroft', 'kmoorcrofte@microsoft.com', '128-521-5948', '995 Amoth Street');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (16, 'Andras', 'McMorland', 'amcmorlandf@flavors.me', '511-712-5694', '3770 Acker Point');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (17, 'Laurens', 'Paulus', 'lpaulusg@unicef.org', '562-261-5269', '54 Kinsman Road');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (18, 'Sylvan', 'Goulter', 'sgoulterh@shareasale.com', '485-179-7973', '2960 Esker Road');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (19, 'Cassey', 'Crang', 'ccrangi@twitter.com', '866-748-2046', '9 Ludington Street');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (20, 'Jock', 'Spenton', 'jspentonj@guardian.co.uk', '954-373-3784', '960 Merrick Hill');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (21, 'Opalina', 'Belliard', 'obelliardk@delicious.com', '407-300-2952', '7 Bartelt Junction');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (22, 'Coral', 'Bertome', 'cbertomel@live.com', '946-986-2305', '94 Graceland Way');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (23, 'Danny', 'Daftor', 'ddaftorm@imageshack.us', '426-468-8957', '61 Lerdahl Lane');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (24, 'Karlyn', 'Barbisch', 'kbarbischn@yahoo.com', '442-974-8474', '9459 Carioca Place');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (25, 'Courtney', 'Hardson', 'chardsono@opensource.org', '640-214-6090', '70205 Warner Terrace');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (26, 'Tedd', 'Smieton', 'tsmietonp@merriam-webster.com', '158-567-4944', '35341 Loftsgordon Hill');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (27, 'Robinet', 'Chugg', 'rchuggq@redcross.org', '372-415-2188', '133 Mallard Drive');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (28, 'Craig', 'Mityukov', 'cmityukovr@blog.com', '525-513-0028', '918 Lighthouse Bay Road');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (29, 'Sonja', 'Giovanizio', 'sgiovanizios@sciencedaily.com', '134-146-1713', '76 Eagan Court');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (30, 'Forbes', 'Quibell', 'fquibellt@woothemes.com', '751-699-3238', '57510 Hallows Hill');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (31, 'Alasdair', 'London', 'alondonu@sohu.com', '428-684-0177', '46 Eagle Crest Drive');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (32, 'Kassi', 'Orlton', 'korltonv@omniture.com', '443-372-6518', '29348 Forest Run Avenue');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (33, 'Ynes', 'Reolfo', 'yreolfow@e-recht24.de', '582-568-9500', '6 Nova Avenue');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (34, 'Jenilee', 'Paladino', 'jpaladinox@typepad.com', '695-690-6857', '6068 Bluejay Trail');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (35, 'Britni', 'Billington', 'bbillingtony@so-net.ne.jp', '891-841-9630', '8 Huxley Crossing');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (36, 'Bradney', 'Philippeaux', 'bphilippeauxz@4shared.com', '323-461-6501', '5222 Oneill Circle');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (37, 'Isidora', 'Kehri', 'ikehri10@earthlink.net', '622-554-5411', '16261 Gulseth Hill');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (38, 'Lotta', 'Marnane', 'lmarnane11@wsj.com', '757-791-3675', '3835 Florence Parkway');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (39, 'Sibel', 'Lamont', 'slamont12@mapy.cz', '455-348-7719', '687 Beilfuss Court');
insert into adopter (adopter_id, first_name, last_name, email, phone, address) values (40, 'Laina', 'Karchewski', 'lkarchewski13@cornell.edu', '431-333-3384', '26 Garrison Avenue');

insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (1, 'Felic', 'Gilfether', 'fgilfether0@myspace.com', 'hashed_pass_1', '503 Mcbride Alley', '2025-03-28');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (2, 'Ethelda', 'Golby', 'egolby1@behance.net', 'hashed_pass_2', '7863 Summerview Hill', '2025-05-12');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (3, 'Briney', 'Cluet', 'bcluet2@sitemeter.com', 'hashed_pass_3', '31895 Susan Point', '2025-08-25');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (4, 'Murdock', 'Samsonsen', 'msamsonsen3@wisc.edu', 'hashed_pass_4', '97 Luster Way', '2025-03-08');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (5, 'Guilbert', 'Robbel', 'grobbel4@independent.co.uk', 'hashed_pass_5', '7433 Corry Point', '2025-04-17');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (6, 'Ansell', 'Vaune', 'avaune5@gravatar.com', 'hashed_pass_6', '90 Waxwing Pass', '2025-01-18');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (7, 'Anselma', 'Drinkhall', 'adrinkhall6@a8.net', 'hashed_pass_7', '5147 Prairie Rose Point', '2025-02-23');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (8, 'Ameline', 'Annis', 'aannis7@nhs.uk', 'hashed_pass_8', '77199 Arkansas Alley', '2025-12-15');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (9, 'Gates', 'Wrigley', 'gwrigley8@disqus.com', 'hashed_pass_9', '44 Burrows Circle', '2025-02-14');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (10, 'Jaclyn', 'Balogh', 'jbalogh9@cargocollective.com', 'hashed_pass_10', '91 Butternut Parkway', '2025-10-06');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (11, 'Golda', 'Lauga', 'glaugaa@psu.edu', 'hashed_pass_11', '0 Lillian Street', '2025-01-28');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (12, 'Feodora', 'Gooderick', 'fgooderickb@dailymotion.com', 'hashed_pass_12', '42714 Vera Circle', '2025-07-14');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (13, 'Leilah', 'Haresnape', 'lharesnapec@istockphoto.com', 'hashed_pass_13', '207 Bobwhite Alley', '2025-11-09');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (14, 'Elliott', 'Copley', 'ecopleyd@livejournal.com', 'hashed_pass_14', '49 Schmedeman Terrace', '2025-01-28');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (15, 'Teriann', 'Lighterness', 'tlighternesse@1688.com', 'hashed_pass_15', '2306 Lunder Plaza', '2025-10-02');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (16, 'Donovan', 'Rubra', 'drubraf@wordpress.org', 'hashed_pass_16', '92 Sloan Plaza', '2025-09-12');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (17, 'Kizzie', 'Walenta', 'kwalentag@tiny.cc', 'hashed_pass_17', '3745 Mariners Cove Avenue', '2025-05-05');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (18, 'Rouvin', 'Service', 'rserviceh@baidu.com', 'hashed_pass_18', '924 Chinook Avenue', '2025-09-14');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (19, 'Ari', 'Skaife', 'askaifei@tiny.cc', 'hashed_pass_19', '32505 Linden Way', '2025-09-12');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (20, 'Cortie', 'Grinley', 'cgrinleyj@themeforest.net', 'hashed_pass_20', '0 Gateway Court', '2025-04-17');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (21, 'Grace', 'Faustin', 'gfaustink@istockphoto.com', 'hashed_pass_21', '38 Leroy Point', '2025-01-02');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (22, 'Will', 'Ferras', 'wferrasl@wufoo.com', 'hashed_pass_22', '3 Jenna Plaza', '2025-04-15');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (23, 'Sheba', 'Blueman', 'sbluemanm@nhs.uk', 'hashed_pass_23', '7763 Debra Junction', '2025-09-18');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (24, 'Ronnica', 'Stitfall', 'rstitfalln@ycombinator.com', 'hashed_pass_24', '697 8th Junction', '2025-09-03');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (25, 'Ced', 'Maryon', 'cmaryono@businessweek.com', 'hashed_pass_25', '22 Sachs Drive', '2025-10-21');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (26, 'Clarine', 'Chatan', 'cchatanp@npr.org', 'hashed_pass_26', '6387 Hermina Plaza', '2025-02-21');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (27, 'Miller', 'Garrud', 'mgarrudq@jimdo.com', 'hashed_pass_27', '77856 Superior Avenue', '2025-08-11');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (28, 'Dylan', 'Woodlands', 'dwoodlandsr@shutterfly.com', 'hashed_pass_28', '672 Fieldstone Pass', '2025-06-05');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (29, 'Wylma', 'Marages', 'wmaragess@stanford.edu', 'hashed_pass_29', '93392 Buhler Road', '2025-11-12');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (30, 'Tuck', 'Aizikov', 'taizikovt@dion.ne.jp', 'hashed_pass_30', '69066 Valley Edge Park', '2025-05-02');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (31, 'Bone', 'Goodhay', 'bgoodhayu@japanpost.jp', 'hashed_pass_31', '040 Grayhawk Crossing', '2025-07-23');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (32, 'Gerome', 'Benard', 'gbenardv@about.com', 'hashed_pass_32', '44200 Hoffman Way', '2025-05-16');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (33, 'Denny', 'Serginson', 'dserginsonw@sourceforge.net', 'hashed_pass_33', '42 Eagan Place', '2025-11-17');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (34, 'Virgina', 'Ogborn', 'vogbornx@bizjournals.com', 'hashed_pass_34', '89 Debra Way', '2025-07-03');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (35, 'Torrey', 'Northern', 'tnortherny@wikispaces.com', 'hashed_pass_35', '23 Claremont Pass', '2025-03-16');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (36, 'Desiri', 'Anslow', 'danslowz@springer.com', 'hashed_pass_36', '189 Red Cloud Lane', '2025-09-10');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (37, 'Kirbee', 'Grishmanov', 'kgrishmanov10@ustream.tv', 'hashed_pass_37', '59019 Logan Lane', '2025-01-11');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (38, 'Timi', 'Iannini', 'tiannini11@go.com', 'hashed_pass_38', '18 Ruskin Pass', '2025-08-12');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (39, 'Dorolice', 'Etherington', 'detherington12@kickstarter.com', 'hashed_pass_39', '844 Columbus Way', '2025-04-22');
insert into employee (employee_id, first_name, last_name, email, password, address, created_at) values (40, 'Dolley', 'Cheke', 'dcheke13@typepad.com', 'hashed_pass_40', '87288 Kinsman Junction', '2025-05-08');

insert into employee_role (employee_id, role, permissions) values (1, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert into employee_role (employee_id, role, permissions) values (2, 'Analyst', 'view_animals,view_reports');
insert into employee_role (employee_id, role, permissions) values (3, 'Volunteer', 'view_animals');
insert into employee_role (employee_id, role, permissions) values (4, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert into employee_role (employee_id, role, permissions) values (5, 'Admin', 'view_animals,edit_animals,manage_adoptions,view_reports,manage_employees');
insert into employee_role (employee_id, role, permissions) values (6, 'Volunteer', 'view_animals');
insert into employee_role (employee_id, role, permissions) values (7, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert into employee_role (employee_id, role, permissions) values (8, 'Analyst', 'view_animals,view_reports');
insert into employee_role (employee_id, role, permissions) values (9, 'Volunteer', 'view_animals');
insert into employee_role (employee_id, role, permissions) values (10, 'Staff', 'view_animals,edit_animals');
insert into employee_role (employee_id, role, permissions) values (11, 'Admin', 'view_animals,edit_animals,manage_adoptions,view_reports,manage_employees');
insert into employee_role (employee_id, role, permissions) values (12, 'Volunteer', 'view_animals');
insert into employee_role (employee_id, role, permissions) values (13, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert into employee_role (employee_id, role, permissions) values (14, 'Analyst', 'view_animals,view_reports');
insert into employee_role (employee_id, role, permissions) values (15, 'Volunteer', 'view_animals');
insert into employee_role (employee_id, role, permissions) values (16, 'Staff', 'view_animals,edit_animals');
insert into employee_role (employee_id, role, permissions) values (17, 'Admin', 'view_animals,edit_animals,manage_adoptions,view_reports,manage_employees');
insert into employee_role (employee_id, role, permissions) values (18, 'Volunteer', 'view_animals');
insert into employee_role (employee_id, role, permissions) values (19, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert into employee_role (employee_id, role, permissions) values (20, 'Analyst', 'view_animals,view_reports');
insert into employee_role (employee_id, role, permissions) values (21, 'Volunteer', 'view_animals');
insert into employee_role (employee_id, role, permissions) values (22, 'Staff', 'view_animals,edit_animals');
insert into employee_role (employee_id, role, permissions) values (23, 'Admin', 'view_animals,edit_animals,manage_adoptions,view_reports,manage_employees');
insert into employee_role (employee_id, role, permissions) values (24, 'Volunteer', 'view_animals');
insert into employee_role (employee_id, role, permissions) values (25, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert into employee_role (employee_id, role, permissions) values (26, 'Analyst', 'view_animals,view_reports');
insert into employee_role (employee_id, role, permissions) values (27, 'Volunteer', 'view_animals');
insert into employee_role (employee_id, role, permissions) values (28, 'Staff', 'view_animals,edit_animals');
insert into employee_role (employee_id, role, permissions) values (29, 'Admin', 'view_animals,edit_animals,manage_adoptions,view_reports,manage_employees');
insert into employee_role (employee_id, role, permissions) values (30, 'Volunteer', 'view_animals');
insert into employee_role (employee_id, role, permissions) values (31, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert into employee_role (employee_id, role, permissions) values (32, 'Analyst', 'view_animals,view_reports');
insert into employee_role (employee_id, role, permissions) values (33, 'Volunteer', 'view_animals');
insert into employee_role (employee_id, role, permissions) values (34, 'Staff', 'view_animals,edit_animals');
insert into employee_role (employee_id, role, permissions) values (35, 'Admin', 'view_animals,edit_animals,manage_adoptions,view_reports,manage_employees');
insert into employee_role (employee_id, role, permissions) values (36, 'Volunteer', 'view_animals');
insert into employee_role (employee_id, role, permissions) values (37, 'Staff', 'view_animals,edit_animals,manage_adoptions');
insert into employee_role (employee_id, role, permissions) values (38, 'Analyst', 'view_animals,view_reports');
insert into employee_role (employee_id, role, permissions) values (39, 'Volunteer', 'view_animals');
insert into employee_role (employee_id, role, permissions) values (40, 'Staff', 'view_animals,edit_animals');

insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (1, 1, 1, 1, 'Updated', 'Medical check-up for dog named Max', 'Feeding schedule for rabbit named Floppy', 'breed', '2006-10-27');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (2, 2, 2, 2, 'Created', 'Medical check-up for dog named Max', 'Adoption of cat named Whiskers', 'breed', '2023-02-08');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (3, 3, 3, 3, 'Status Change', 'Playtime for guinea pig named Peanut', 'Feeding schedule for rabbit named Floppy', 'weight', '2012-10-27');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (4, 4, 4, 4, 'Updated', 'Medical check-up for dog named Max', 'Medical check-up for dog named Max', 'weight', '2025-08-25');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (5, 5, 5, 5, 'Status Change', 'Feeding schedule for rabbit named Floppy', 'Medical check-up for dog named Max', 'weight', '2025-06-20');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (6, 6, 6, 6, 'Deleted', 'Medical check-up for dog named Max', 'Adoption of cat named Whiskers', 'adoption status', '2025-10-05');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (7, 7, 7, 7, 'Status Change', 'Adoption of cat named Whiskers', 'Playtime for guinea pig named Peanut', 'weight', '2025-08-26');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (8, 8, 8, 8, 'Updated', 'Feeding schedule for rabbit named Floppy', 'Feeding schedule for rabbit named Floppy', 'weight', '2025-09-27');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (9, 9, 9, 9, 'Updated', 'Adoption of cat named Whiskers', 'Adoption of cat named Whiskers', 'age', '2025-10-24');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (10, 10, 10, 10, 'Updated', 'Medical check-up for dog named Max', 'Medical check-up for dog named Max', 'breed', '2025-08-13');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (11, 11, 11, 11, 'Updated', 'Adoption of cat named Whiskers', 'Feeding schedule for rabbit named Floppy', 'adoption status', '2025-04-10');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (12, 12, 12, 12, 'Deleted', 'Adoption of cat named Whiskers', 'Medical check-up for dog named Max', 'breed', '2025-09-12');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (13, 13, 13, 13, 'Created', 'Playtime for guinea pig named Peanut', 'Playtime for guinea pig named Peanut', 'breed', '2025-01-29');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (14, 14, 14, 14, 'Created', 'Adoption of cat named Whiskers', 'Feeding schedule for rabbit named Floppy', 'breed', '2025-02-24');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (15, 15, 15, 15, 'Deleted', 'Adoption of cat named Whiskers', 'Playtime for guinea pig named Peanut', 'adoption status', '2025-06-19');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (16, 16, 16, 16, 'Updated', 'Adoption of cat named Whiskers', 'Medical check-up for dog named Max', 'weight', '2025-04-04');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (17, 17, 17, 17, 'Deleted', 'Playtime for guinea pig named Peanut', 'Medical check-up for dog named Max', 'weight', '2025-06-02');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (18, 18, 18, 18, 'Updated', 'Feeding schedule for rabbit named Floppy', 'Playtime for guinea pig named Peanut', 'age', '2025-05-18');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (19, 19, 19, 19, 'Created', 'Medical check-up for dog named Max', 'Playtime for guinea pig named Peanut', 'name', '2025-08-21');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (20, 20, 20, 20, 'Created', 'Medical check-up for dog named Max', 'Adoption of cat named Whiskers', 'age', '2025-10-10');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (21, 21, 21, 21, 'Deleted', 'Feeding schedule for rabbit named Floppy', 'Adoption of cat named Whiskers', 'breed', '2025-07-19');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (22, 22, 22, 22, 'Status Change', 'Medical check-up for dog named Max', 'Feeding schedule for rabbit named Floppy', 'age', '2025-05-07');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (23, 23, 23, 23, 'Updated', 'Playtime for guinea pig named Peanut', 'Feeding schedule for rabbit named Floppy', 'breed', '2025-03-13');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (24, 24, 24, 24, 'Updated', 'Playtime for guinea pig named Peanut', 'Medical check-up for dog named Max', 'adoption status', '2025-05-31');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (25, 25, 25, 25, 'Created', 'Feeding schedule for rabbit named Floppy', 'Adoption of cat named Whiskers', 'breed', '2025-04-22');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (26, 26, 26, 26, 'Created', 'Playtime for guinea pig named Peanut', 'Medical check-up for dog named Max', 'age', '2025-02-27');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (27, 27, 27, 27, 'Status Change', 'Adoption of cat named Whiskers', 'Feeding schedule for rabbit named Floppy', 'adoption status', '2025-02-24');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (28, 28, 28, 28, 'Created', 'Feeding schedule for rabbit named Floppy', 'Adoption of cat named Whiskers', 'name', '2025-10-14');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (29, 29, 29, 29, 'Created', 'Playtime for guinea pig named Peanut', 'Adoption of cat named Whiskers', 'name', '2025-09-07');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (30, 30, 30, 30, 'Deleted', 'Feeding schedule for rabbit named Floppy', 'Playtime for guinea pig named Peanut', 'age', '2025-04-05');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (31, 31, 31, 31, 'Created', 'Playtime for guinea pig named Peanut', 'Playtime for guinea pig named Peanut', 'adoption status', '2025-04-04');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (32, 32, 32, 32, 'Deleted', 'Medical check-up for dog named Max', 'Medical check-up for dog named Max', 'name', '2025-10-12');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (33, 33, 33, 33, 'Status Change', 'Medical check-up for dog named Max', 'Playtime for guinea pig named Peanut', 'weight', '2025-02-03');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (34, 34, 34, 34, 'Status Change', 'Adoption of cat named Whiskers', 'Feeding schedule for rabbit named Floppy', 'weight', '2025-08-24');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (35, 35, 35, 35, 'Updated', 'Medical check-up for dog named Max', 'Playtime for guinea pig named Peanut', 'adoption status', '2025-08-29');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (36, 36, 36, 36, 'Created', 'Feeding schedule for rabbit named Floppy', 'Medical check-up for dog named Max', 'adoption status', '2025-07-09');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (37, 37, 37, 37, 'Updated', 'Playtime for guinea pig named Peanut', 'Medical check-up for dog named Max', 'name', '2025-10-23');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (38, 38, 38, 38, 'Created', 'Feeding schedule for rabbit named Floppy', 'Medical check-up for dog named Max', 'breed', '2025-03-07');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (39, 39, 39, 39, 'Deleted', 'Feeding schedule for rabbit named Floppy', 'Feeding schedule for rabbit named Floppy', 'adoption status', '2025-09-09');
insert into audit_log (log_id, animal_id, employee_id, adopter_id, action, old_value, new_value, field_changed, changed_at) values (40, 40, 40, 40, 'Updated', 'Adoption of cat named Whiskers', 'Medical check-up for dog named Max', 'adoption status', '2025-01-24');

insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (1, 1, 1, 'Completed', 'Loves belly rubs', '2006-05-28', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (2, 2, 2, 'Under Review', 'Needs a yard to run', '2023-08-31', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (3, 3, 3, 'Pending', 'Loves belly rubs', '2012-04-02', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (4, 4, 4, 'Approved', 'Needs a yard to run', '2020-04-26', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (5, 5, 5, 'Pending', 'Shy at first', '2004-05-10', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (6, 6, 6, 'Denied', 'Needs a yard to run', '2011-06-09', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (7, 7, 7, 'Approved', 'House trained', '2022-07-11', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (8, 8, 8, 'Denied', 'Good with kids', '2006-04-24', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (9, 9, 9, 'Pending', 'House trained', '2024-02-01', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (10, 10, 10, 'Under Review', 'House trained', '2016-08-10', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (11, 11, 11, 'Under Review', 'Needs a yard to run', '2024-11-10', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (12, 12, 12, 'Withdrawn', 'House trained', '2008-08-02', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (13, 13, 13, 'Approved', 'Loves belly rubs', '2018-06-03', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (14, 14, 14, 'Approved', 'House trained', '2018-08-11', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (15, 15, 15, 'Completed', 'Loves belly rubs', '2003-02-05', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (16, 16, 16, 'Under Review', 'Shy at first', '2006-07-16', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (17, 17, 17, 'Approved', 'Good with kids', '2005-10-08', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (18, 18, 18, 'Denied', 'House trained', '2000-06-05', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (19, 19, 19, 'Withdrawn', 'Good with kids', '2021-04-28', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (20, 20, 20, 'Withdrawn', 'Loves belly rubs', '2020-03-25', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (21, 21, 21, 'Completed', 'Good with kids', '2006-06-11', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (22, 22, 22, 'Pending', 'Good with kids', '2007-11-15', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (23, 23, 23, 'Approved', 'Good with kids', '2004-10-07', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (24, 24, 24, 'Withdrawn', 'Shy at first', '2024-09-07', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (25, 25, 25, 'Under Review', 'House trained', '2011-06-06', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (26, 26, 26, 'Withdrawn', 'Shy at first', '2022-03-11', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (27, 27, 27, 'Approved', 'Shy at first', '2016-03-23', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (28, 28, 28, 'Approved', 'Shy at first', '2019-01-07', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (29, 29, 29, 'Completed', 'Needs a yard to run', '2004-03-29', '2025-04-15');
insert into application (application_id, adopter_id, animal_id, status, notes, submission_date, decision_date) values (30, 30, 30, 'Pending', 'Good with kids', '2003-02-28', '2025-04-15');

insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (1, 'Vomiting after meals', 'Jane Smith', '2012-10-13', 'Medication', 1);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (2, 'Vomiting after meals', 'Michael Johnson', '2013-03-15', 'Checkup', 2);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (3, 'Limping on left hind leg', 'Robert Brown', '2008-04-02', 'Medication', 3);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (4, 'Heart rate normal', 'Emily Davis', '2012-04-18', 'Checkup', 4);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (5, 'Heart rate normal', 'Emily Davis', '2014-12-17', 'Vaccination', 5);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (6, 'Vomiting after meals', 'Michael Johnson', '2011-06-22', 'Medication', 6);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (7, 'Loss of appetite', 'Michael Johnson', '2018-01-26', 'Surgery', 7);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (8, 'Sneezing frequently', 'Michael Johnson', '2019-05-19', 'Treatment', 8);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (9, 'Sneezing frequently', 'Emily Davis', '2018-08-08', 'Vaccination', 9);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (10, 'Heart rate normal', 'Robert Brown', '2025-11-25', 'Spray/Neuter', 10);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (11, 'Vomiting after meals', 'Jane Smith', '2007-02-11', 'Spray/Neuter', 11);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (12, 'Sneezing frequently', 'John Doe', '2022-08-24', 'Checkup', 12);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (13, 'Limping on left hind leg', 'Robert Brown', '2005-02-18', 'Spray/Neuter', 13);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (14, 'Vomiting after meals', 'Michael Johnson', '2007-01-19', 'Surgery', 14);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (15, 'Heart rate normal', 'Michael Johnson', '2001-09-24', 'Vaccination', 15);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (16, 'Limping on left hind leg', 'John Doe', '2000-11-30', 'Treatment', 16);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (17, 'Limping on left hind leg', 'John Doe', '2024-03-30', 'Treatment', 17);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (18, 'Vomiting after meals', 'John Doe', '2008-12-14', 'Treatment', 18);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (19, 'Limping on left hind leg', 'Jane Smith', '2024-01-18', 'Checkup', 19);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (20, 'Loss of appetite', 'Jane Smith', '2016-01-09', 'Vaccination', 20);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (21, 'Vomiting after meals', 'Michael Johnson', '2005-12-18', 'Surgery', 21);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (22, 'Vomiting after meals', 'Jane Smith', '2001-11-24', 'Spray/Neuter', 22);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (23, 'Limping on left hind leg', 'Emily Davis', '2020-02-24', 'Surgery', 23);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (24, 'Loss of appetite', 'John Doe', '2024-11-18', 'Vaccination', 24);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (25, 'Loss of appetite', 'Michael Johnson', '2005-02-18', 'Medication', 25);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (26, 'Loss of appetite', 'Emily Davis', '2002-03-23', 'Surgery', 26);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (27, 'Heart rate normal', 'Robert Brown', '2000-10-13', 'Surgery', 27);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (28, 'Vomiting after meals', 'Emily Davis', '2018-03-20', 'Vaccination', 28);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (29, 'Sneezing frequently', 'Robert Brown', '2007-07-18', 'Vaccination', 29);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (30, 'Vomiting after meals', 'Jane Smith', '2005-11-21', 'Vaccination', 30);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (31, 'Heart rate normal', 'Jane Smith', '2006-10-03', 'Surgery', 31);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (32, 'Vomiting after meals', 'Robert Brown', '2006-01-09', 'Vaccination', 32);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (33, 'Loss of appetite', 'Jane Smith', '2020-11-09', 'Surgery', 33);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (34, 'Limping on left hind leg', 'Michael Johnson', '2023-10-20', 'Checkup', 34);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (35, 'Vomiting after meals', 'Michael Johnson', '2001-08-12', 'Medication', 35);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (36, 'Heart rate normal', 'John Doe', '2010-11-18', 'Treatment', 36);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (37, 'Loss of appetite', 'John Doe', '2008-03-06', 'Surgery', 37);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (38, 'Heart rate normal', 'Michael Johnson', '2020-01-16', 'Medication', 38);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (39, 'Heart rate normal', 'Michael Johnson', '2005-03-03', 'Surgery', 39);
insert into medical_record (record_id, notes, practitioner_name, admin_date, category, animal_id) values (40, 'Heart rate normal', 'Robert Brown', '2015-12-19', 'Treatment', 40);

insert into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (1, 1, '2007-01-26', '2011-06-21', 274, 75.15, 197.89);
insert into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (2, 2, '2010-07-12', '2016-05-13', 24, 213.74, 118.82);
insert into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (3, 3, '2025-12-30', '2008-02-21', 489, 270.38, 158.14);
insert into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (4, 4, '2019-01-25', '2023-04-23', 603, 123.47, 125.44);
insert into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (5, 5, '2001-06-02', '2009-01-29', 696, 83.32, 289.43);
insert into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (6, 6, '2025-05-03', '2012-08-10', 72, 110.02, 56.61);
insert into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (7, 7, '2001-02-05', '2017-10-13', 908, 345.4, 342.61);
insert into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (8, 8, '2012-11-04', '2012-12-20', 102, 23.21, 159.35);
insert into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (9, 9, '2010-05-09', '2022-04-25', 978, 197.81, 18.45);
insert into monthly_report (report_id, template_id, report_month, generated_date, total_adopted, avg_days_to_adopt, avg_length_of_stay) values (10, 10, '2023-08-09', '2024-11-17', 918, 155.37, 162.31);

insert into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (1, 'Q1 Adoptions', false, 'PDF', 'Total Adopted', '2007-01-01', '2007-03-31');
insert into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (2, 'Mid-Year Review', false, 'CSV', 'Species Breakdown', '2010-07-01', '2010-09-30');
insert into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (3, 'Year End 2025', false, 'PDF', 'Total Adopted,Average Days to Adopt', '2025-01-01', '2025-12-31');
insert into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (4, 'Q1 2019', false, 'Excel', 'Average Length of Stay', '2019-01-01', '2019-03-31');
insert into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (5, 'Archived 2001', true, 'PDF', 'Total Adopted', '2001-01-01', '2001-12-31');
insert into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (6, 'Spring 2025', false, 'CSV', 'Intake Count', '2025-03-01', '2025-05-31');
insert into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (7, 'Early 2001', true, 'PDF', 'Species Breakdown', '2001-01-01', '2001-06-30');
insert into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (8, 'Fall 2012', false, 'Excel', 'Total Adopted,Average Length of Stay', '2012-09-01', '2012-11-30');
insert into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (9, 'Spring 2010', false, 'CSV', 'Average Days to Adopt', '2010-03-01', '2010-05-31');
insert into report_template (template_id, template_name, is_archived, export_format, metric_included, date_range_start, date_range_end) values (10, 'Summer 2023', false, 'PDF', 'Total Adopted,Species Breakdown', '2023-06-01', '2023-08-31');