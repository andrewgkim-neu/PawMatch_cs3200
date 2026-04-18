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

st.title(f"Schedule an Appointment with {animal_name}")
st.write("Pick a date and time to visit the shelter, and we'll confirm your appointment!")


# Get inputs for date and time preferences
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


notes = st.text_area("Please provide any additional notes for the shelter staff (optional)", placeholder = "e.g. I have another pet at home, allergies, etc.")

st.divider()


# submit the appointment
if st.button("Confirm Appointment", type = "primary", use_container_width = True):
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
                st.success(f"Appointment booked for {appt_date.strftime('%B %d, %Y')} at {appt_time.strftime('%I:%M %p')}")
                st.balloons()
            else:
                st.error(f"Something went wrong: {response.text}")
        except Exception as e:
            st.error(f"Could not connect to the server: {e}")

# Button to go back to the pet 
if st.button("Back to Pet Profile"):
    st.switch_page('pages/02_Pet_Profile.py')

