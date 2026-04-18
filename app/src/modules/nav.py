# Idea borrowed from https://github.com/fsmosca/sample-streamlit-authenticator

# This file has functions to add links to the left sidebar based on the user's role.

import streamlit as st


# ---- General ----------------------------------------------------------------

def home_nav():
    st.sidebar.page_link("Home.py", label="Home", icon="🏠")


def about_page_nav():
    st.sidebar.page_link("pages/40_About.py", label="About", icon="🧠")


# ---- Role: adopter ------------------------------------------------

def adopter_home_nav():
    st.sidebar.page_link(
        "pages/00_Adopter.py", label="Adopter Home", icon="👤"
    )

def specific_animal_info_nav():
    st.sidebar.page_link(
        "pages/01_Browse_Animals.py", label="Discover the Animals", icon="🐶"
    )

def schedule_appointment_nav():
    st.sidebar.page_link(
        "pages/03_Schedule_Appointment.py", label="Schedule an Appointment", icon="🗓️"
    )

def find_match_nav():
    st.sidebar.page_link(
        "pages/04_Adoption_Application.py", label="Submit an Application", icon="📝"
    )


# ---- Role: system_admin -----------------------------------------------------

def system_admin_nav():
    st.sidebar.page_link(
        "pages/10_System_Admin_Home.py", label="System Admin Home", icon="🏠"
    )

def add_new_animal_nav():
    st.sidebar.page_link("pages/14_Add_New_Animal.py", label="Input New Animal", icon="📁")


def add_new_employee_nav():
    st.sidebar.page_link("pages/15_Add_New_Employee.py", label="Add New Employee", icon="➕")

# ---- Role: data_analyst ----------------------------------------------------

def data_analyst_home_nav():
    st.sidebar.page_link("pages/20_Data_Analyst_Home.py", label="Data Analyst", icon="💻")


def dashboard_nav():
    st.sidebar.page_link(
        "pages/21_Dashboard.py", label="Dashboard", icon="📊"
    )

def report_nav():
    st.sidebar.page_link(
        "pages/22_Report.py", label="Report", icon="📋"
    )

# ---- Role: shelter_staff ----------------------------------------------------

def shelter_staff_home_nav():
    st.sidebar.page_link("pages/30_Shelter_Staff_Home.py", label="Shelter Staff", icon="💼")


def current_animals_nav():
    st.sidebar.page_link(
        "pages/31_Current_Animals.py", label="Current Animals in Shelter", icon="🐹"
    )

def adoption_applications_nav():
    st.sidebar.page_link(
        "pages/32_Adoption_Applications.py", label="Adoption Applications", icon="📋"
    )

def medical_records_nav():
    st.sidebar.page_link(
        "pages/33_Medical_Records.py", label="Animal Medical Records", icon="💉"
    )

# ---- Sidebar assembly -------------------------------------------------------

def SideBarLinks(show_home=False):
    """
    Renders sidebar navigation links based on the logged-in user's role.
    The role is stored in st.session_state when the user logs in on Home.py.
    """

    # Logo appears at the top of the sidebar on every page
    st.sidebar.image("assets/logo.png", width=150)

    # If no one is logged in, send them to the Home (login) page
    if "authenticated" not in st.session_state:
        st.session_state.authenticated = False
        st.switch_page("Home.py")

    if show_home:
        home_nav()

    if st.session_state["authenticated"]:

        if st.session_state["role"] == "adopter":
            adopter_home_nav()
            specific_animal_info_nav()
            find_match_nav()

        if st.session_state["role"] == "system_admin":
            system_admin_nav()
            add_new_animal_nav()
            add_new_employee_nav()


        if st.session_state["role"] == "data_analyst":
            data_analyst_home_nav()
            dashboard_nav()
            report_nav()

        if st.session_state["role"] == "shelter_staff":
            shelter_staff_home_nav()
            current_animals_nav()
            adoption_applications_nav()
            medical_records_nav()

    # About link appears at the bottom for all roles
    about_page_nav()

    if st.session_state["authenticated"]:
        if st.sidebar.button("Logout"):
            del st.session_state["role"]
            del st.session_state["authenticated"]
            st.switch_page("Home.py")
