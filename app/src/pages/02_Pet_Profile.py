import logging
logger = logging.getLogger(__name__)
import streamlit as st
import pandas as pd
import pydeck as pdk
import requests
from urllib.error import URLError
from modules.nav import SideBarLinks

API = 'http://web-api:4000'

st.set_page_config(layout='wide')

SideBarLinks()

if 'selected_animal_id' not in st.session_state:
    st.warning("No animal selected. Please return to the search page.")
    if st.button("Back to Browse"):
        st.switch_page('pages/01_Browse_Animals.py')
    st.stop()

animal_id = st.session_state['selected_animal_id']

animal = None
vaccines = []

try:
    r = requests.get(f"{API}/animals/{animal_id}")
    if r.status_code == 200:
        animal = r.json()
    else:
        st.error("Could not load this animal's profile")
except requests.exceptions.RequestExceotion as e:
    st.error(f"Error connecting to the API: {str(e)}")


try:
    r2 = requests.get(f"{API}/animals/{animal_id}/medical-records")
    if r2.status_code == 200:
        records = r2.json()
        vaccines = [
            rec.get('vaccine_name') or rec.get('record_type', 'Unknown shot')
            for rec in records
            if rec.get('record_type', '').lower() == 'vaccination'
                or rec.get('vaccine_name')
        ]

except requests.exceptions.RequestException:
    vaccines = []

if not animal:
    st.stop()

if st.button("Back to Browse"):
    st.switch_page('pages/01_Browse_Animals.py')

st.title(f"All About {animal.get('name', 'Unknown')}:")
st.divider()

photo_col, info_col = st.columns([1, 2], gap='large')

with photo_col:
    st.image("assets/animal.png", use_container_width=True)
    st.write("")

    if st.button("Schedule Meet & Greet", use_container_width=True):
        st.session_state['selected_animal_id'] = animal['animal_id']
        st.session_state['selected_animal_name'] = animal['name'] 
        st.switch_page('pages/03_Schedule_Appointment.py')

with info_col:
    col1, col2 = st.columns(2)
    age_months = animal.get('age_months', 0)
    age_str = f"{age_months // 12} years " + (f"{age_months % 12} months" if age_months % 12 else "")

    with col1:
        st.markdown("**Species**")
        st.write(animal.get('species', 'N/A'))
        st.markdown("**Breed**")
        st.write(animal.get('breed', 'N/A'))
        st.markdown("**Age**")
        st.write(age_str)

    with col2:
        ## ADD ENERGY LEVEL DATA
        st.markdown("**Energy Level**")
        st.write(animal.get('energy_level', 'N/A'))
        ## ADD SIZE DATA
        st.markdown("**Size**")
        st.write(animal.get('size', 'N/A'))
        st.markdown("**Status**")
        status = animal.get('status', 'N/A')
        if status == 'Available':
            st.success(status)
        elif status == 'Adopted':
            st.error(status)
        elif status in ('Pending Adoption', 'Fostered', 'Medical Hold'):
            st.warning(status)
        else:
            st.info(status)

    st.divider()

    ## TODO WRITE BIO FOR ANIMALS -- maybe
    st.markdown("**About Me**")
    bio = animal.get('bio') or "No description available yet for this animal."
    st.caption(bio)

    st.divider()

# Vaccination section
    st.markdown("**Vaccination History**")
    if vaccines:
        badge_html = " ".join(
            f'<span style="background: #E1F5EE; color: #0F6E56; border: 1px solid #5DCAA5;'
            f'border-radius: 20px; padding: 3px 12px; font-size: 13px; margin: 3px; display: inline-block;">'
            f'✓ {v}</span>'
            for v in vaccines
        )
        st.markdown(badge_html, unsafe_allow_html=True)
    else:
        st.caption("No vaccination records on file")



