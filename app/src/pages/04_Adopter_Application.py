import logging
logger = logging.getLogger(__name__)
import streamlit as st
import requests
from datetime import datetime, time, timedelta
from urllib.error import URLError
from modules.nav import SideBarLinks


API = 'http://web-api:4000'

st.set_page_config(layout='wide')
SideBarLinks()

animal_id = st.session_state.get('selected_animal_id')
animal_name = st.session_state.get('selected_animal_name', 'this pet')
adopter_id = st.session_state.get('adopter_id')

st.title(f"Adoption Application")
st.write("Complete this form to begin your application process.")

st.divider()

# default variables
first_name = last_name = email = phone = address = city = state = housing_type = rent = other_pets = notes = ""


if not st.session_state.get('application_submitted'):
    # choose the animal
    st.subheader("Who are you interested in adopting?")

    try:
        response = requests.get(f"{API}/animals")
        animals = response.json()
        animals = [a for a in animals if a['status'] in ('Available', 'Pending Adoption', 'Fostered')]
    except Exception as e:
        st.error(f"Could not load animals: {e}")
        animals = []

    animal_options = {f"{a['name']} ({a['species']})": a for a in animals}
    options_list = ["-Select an animal-"] + list(animal_options.keys())
    selected_label = st.selectbox("Select an animal", options_list, key="animal_selectbox")

    if selected_label != "-Select an animal-":
        selected = animal_options[selected_label]
        st.session_state['selected_animal_id'] = selected['animal_id']
        st.session_state['selected_animal_name'] = selected['name']
        st.session_state['selected_animal_status'] = selected['status']

        # warning for animals with status == 'Pending Adoption'
        if selected['status'] == 'Pending Adoption':
            st.warning(
            f"**{selected['name']} has a pending application.**"
            "\n Another applicant has submitted an application for this animal, but you can still apply."
            f"We will reach out to you with updates in {animal_name}'s status. Please reach out with any questions."
        )
            
        # warning for animals with status == 'Fostered'
        if selected['status'] == 'Fostered':
            st.warning(
                f"**{selected['name']} is currently being fostered.**"
                "\n You are still able to adopt them, but the process may be a bit longer because of this."
            )

    else:
        st.session_state.pop('selected_animal_id', None)
        st.session_state.pop('selected_animal_name', None)
        st.session_state.pop('selected_animal_status', None)

    st.divider()


    # adopter info
    st.subheader("Your Information")
    st.write("Please hit enter after each box.")

    col1, col2 = st.columns(2)
    with col1:
        first_name = st.text_input("First Name")
    with col2:
        last_name = st.text_input("Last Name")

    col3, col4 = st.columns(2)
    with col3:
        email = st.text_input("Email Address")
    with col4:
        phone = st.text_input("Phone Number")

    col5, = st.columns(2)
    with col5:
        address = st.text_input("Street Address")

    st.divider()


    #living situation
    st.subheader("Housing Details")

    col8, col9 = st.columns(2)
    with col8:
        housing_type = st.selectbox("Housing Type", ["", "House", "Apartment", "Other"])
    with col9:
        rent = st.selectbox("Do you own or rent?", ["", "Own", "Rent"])

    other_pets = st.selectbox("Do you have any other pets at home?", 
                            ["", "No", "Yes - dog", "Yes - cat", "Yes - other", "Yes - multiple others"])

    st.divider()

    # additional notes/comments
    st.subheader("Additional Information")

    notes = st.text_area("Anything else you would to share? (optional)", placeholder = "Share any questions, more information about your lifestyle, or why you love this animal!")

    st.divider()


# submit the application
if not st.session_state.get('application_submitted'):
    if st.button("Submit Application", type = "primary", use_container_width = True):
        animal_status = st.session_state.get('selected_animal_status', 'Available')
        if not animal_id or not adopter_id:
            st.error("Missing animal or adopter information. Please try again.")
        elif not first_name or not last_name:
            st.error("Please enter your full name.")
        elif not email:
            st.error("Please enter your email address.")
        elif not phone:
            st.error("Please enter your phone number.")
        elif animal_status == 'Pending Adoption' and not st.session_state.get('awaiting_pending_confirm'):
            st.session_state['awaiting_pending_confirm'] = True
            st.rerun()
        else:
            st.session_state['application_submitted'] = True
            st.rerun()

# 'Pending Adoption' warning before submission
if st.session_state.get('awaiting_pending_confirm'):
    st.warning("There is another application pending ahead of yours, would you still like to submit?")
    col1, col2 = st.columns(2)
    with col1:
        confirm = st.button("Yes, submit anyway", type = "primary", use_container_width = True)
    with col2:
        cancel = st.button("Cancel submission",use_container_width = True)

    if confirm:
        st.session_state.pop('awaiting_pending_confirm', None)
        st.session_state['application_submitted'] = True
        st.rerun()

    if cancel:
        st.session_state.pop('awaiting_pending_confirm', None)
        st.rerun()
        
if st.session_state.get('application_submitted'):
    animal_status = st.session_state.get('selected_animal_status', 'Available')
    if animal_status == 'Pending Adoption':
        st.success(f"Your application for {animal_name} has been submitted and added to the queue!")
        st.info("We will contact you with any updates in status. Please reach out with any questions.")
    else:
        st.success(f"Your application for {animal_name} has been submitted!")
        st.info("We will reach out soon with next steps. Please reach out with any questions.")

    st.balloons()
    if st.button("Start a New Application", type = "primary", use_container_width = True):
        st.session_state.pop('application_submitted', None)
        st.session_state.pop('selected_animal_id', None)
        st.session_state.pop('selected_animal_name', None)
        st.session_state.pop('selected_animal_status', None)
        st.rerun()


# button to go to pet profile
animal_name = st.session_state.get('selected_animal_name', 'Pet')
if st.button(f"Go to {animal_name}'s Profile"):
    st.switch_page('pages/02_Pet_Profile.py')


# button to go back to home page
if st.button("Return to Home"):
    st.switch_page("00_Adopter.py")


