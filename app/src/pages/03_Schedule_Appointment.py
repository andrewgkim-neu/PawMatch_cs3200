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
animal_name = st.session_state.get('selected_animal_name', 'a pet')
adopter_id = st.session_state.get('adopter_id')

st.title(f"Schedule an Appointment with {animal_name}")
st.write("Pick a date and time to visit the shelter, and we'll confirm your appointment!")

st.divider()


if not st.session_state.get('appointment_submitted'):

    # Choose the animal or have it automatically input if coming from profile
    st.subheader("Which pet would you like to meet?")

    try:
        response = requests.get(f"{API}/animals")
        animals = response.json()
        animals = [a for a in animals if a['status'] in ('Available', 'Pending Adoption', 'Fostered')]
    except Exception as e:
        st.error(f"Could not load animals: {e}")
        animals = []

    animal_options = {f"{a['name']} ({a['species']})": a for a in animals}

    prefilled_id = st.session_state.get('selected_animal_id')
    default_label = next((label for label, a in animal_options.items() if a['animal_id'] == prefilled_id), None)
    options_list = ["-Select a Pet-"] + list(animal_options.keys())
    default_index = options_list.index(default_label) if default_label else 0
    selected_label = st.selectbox("Select a pet", options_list, index = default_index, key = "animal_selectbox")

    if selected_label != "-Select a Pet-":
        selected = animal_options[selected_label]
        st.session_state['selected_animal_id'] = selected['animal_id']
        st.session_state['selected_animal_name'] = selected['name']
    else:
        st.session_state.pop('selected_animal_id', None)
        st.session_state.pop('selected_animal_name', None)
 
    st.divider()

   
    # Get inputs for date and time preferences
    st.subheader("When would you like to visit?")
    
    col1, col2 = st.columns(2)
    with col1:
        appt_date = st.date_input(
            "Preferred Date",
            min_value = datetime.today().date() + timedelta(days=1)
        )

    with col2:
        appt_time = st.time_input(
            "Preferred Time",
            value = time(10, 0),
            step = 1800
        )


    # Add an optional notes section
    st.subheader("Additional Information")

    notes = st.text_area("Please provide any additional notes for the shelter staff (optional)", placeholder = "e.g. I have another pet at home, allergies, etc.")

    st.divider()



# submit the appointment
if not st.session_state.get('appointment_submitted'):
    if st.button("Confirm Appointment", type = "primary", use_container_width = True):
        animal_id = st.session_state.get('selected_animal_id')
        adopter_id = st.session_state.get('adopter_id')
        if not animal_id or not adopter_id:
            st.error("Missing animal or adopter information. Please go back and try again.")
        else: 
            scheduled_for = datetime.combine(appt_date, appt_time).strftime('%Y-%m-%d %H:%M:%S')

            payload = {
                "adopter_id" : adopter_id,
                "animal_id" : animal_id,
                "scheduled_for" : scheduled_for,
                "notes" : notes
            }

            try:
                response = requests.post(f"{API}/adopters/appointments", json=payload)
                if response.status_code == 201:
                    st.session_state['appointment_submitted'] = True
                    st.session_state['appointment_date'] = appt_date
                    st.session_state['appointment_time'] = appt_time
                    st.rerun()
                else:
                    st.error(f"Something went wrong: {response.text}")
            except Exception as e:
                st.error(f"Could not connect to the server: {e}")

if st.session_state.get('appointment_submitted'):
    confirmed_name = st.session_state.get('selected_animal_name', 'your pet')
    confirmed_date = st.session_state.get('appointment_date')
    confirmed_time = st.session_state.get('appointment_time')

    st.success(f"Your appointment with {confirmed_name} has been scheduled!")
    if confirmed_date and confirmed_time:
        st.info(f"{confirmed_date.strftime('%B %d, %Y')} at {confirmed_time.strftime('%I:%M %p')}. See you then!")

    st.balloons()

    if st.button("Schedule Another Appointment", type="primary", use_container_width=True):
        st.session_state.pop('appointment_submitted', None)
        st.session_state.pop('appointment_date',      None)
        st.session_state.pop('appointment_time',      None)
        st.session_state.pop('selected_animal_id',    None)
        st.session_state.pop('selected_animal_name',  None)
        st.rerun()

# Button to go to the pet 
if st.button(f"Go to Pet's Profile"):
    st.switch_page('pages/02_Pet_Profile.py')

# Button to go back to home page
if st.button("Return to Home"):
    st.switch_page("pages/00_Adopter.py")

