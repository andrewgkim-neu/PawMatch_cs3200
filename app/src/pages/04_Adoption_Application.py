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

st.title(f"Adoption Application for {animal_name}")
st.write("Complete this form to begin your application process.")

st.divider()


# warning for animals with status = 'Pending Adoption'
animal_status = st.session_state.get('selected_animal_status', 'Available')

if animal_status == 'Pending Adoption':
    st.warning(
        f"**{animal_name} has a pending application.**"
        "Another applicant has submitted an application for this animal, but you can still apply."
        f"We will reach out to you if {animal_name} is not adopted."
    )


# adopter info
st.subheader("Your Information")

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

col5, col6 = st.columns(2)
with col5:
    address = st.text_input("Street Address")
with col6:
    city = st.text_input("City")

st.divider()


#living situation
st.subheader("Housing Details")

col7, col8 = st.columns(2)
with col7:
    housing_type = st.selectbox("Housing Type", ["", "House", "Apartment", "Other"])
with col8:
    rent = st.selectbox("Do you own or rent?", ["", "Own", "Rent"])

other_pets = st.selectbox("Do you have any other pets at home?", 
                          ["", "No", "Yes - dog", "Yes - cat", "Yes - other", "Yes - multiple others"])

st.divider()

# additional notes/comments
st.subheader("Additional Information")

notes = st.text_area("Anything else you would to share? (optional)", placeholder = "Share any questions, more information about your lifestyle, or why you love this animal!")

st.divider()


# submit the application
if st.button("Submit Application", type = "primary", use_container_width = True):
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
        st.success(f"Your application for {animal_name} has been submitted!")
        if animal_status == 'Pending Adoption':
            st.info("Since there is a pending application ahead of yours, we will reach out to you with any updates.")
        st.balloons()
        st.session_state.pop('awaiting_pending_confirm', None)


# 'Pending Application' warning before submission
if st.session_state.get('awaiting_pending_confirm'):
    st.warning("There is another application pending ahead of yours, would you still like to submit?")
    col1, col2 = st.columns(2)
    with col1:
        if st.button("Yes, submit anyway", type = "primary", use_container_width=True):
            st.success(f"Your application for {animal_name} has been submitted and added to the queue!")
            st.info("We will contact you with any updates in status.")
            st.balloons()
            st.session_state.pop('awaiting_pending_confirm', None)
    with col2:
        if st.button("Cancel application submission", use_container_width = True):
            st.session_state.pop('awaiting_pending_confirm', None)
            st.rerun()

# button to go to pet profile
if st.button("Go to Pet Profile"):
    st.switch_page('pages/02_Pet_Profile.py')

# button to go back to home page
if st.button("Return to Home"):
    st.switch_page("00_Adopter.py")


