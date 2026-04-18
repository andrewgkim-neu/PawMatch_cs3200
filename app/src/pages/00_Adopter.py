import logging
logger = logging.getLogger(__name__)
import streamlit as st
from modules.nav import SideBarLinks

st.set_page_config(layout='wide')

# Show appropriate sidebar links for the role of the currently logged in user
SideBarLinks()

st.title(f"Welcome Adopter, {st.session_state['first_name']}.")
st.write('### What would you like to do today?')

if st.button('Discover the Animals!',
             type='primary',
             use_container_width=True):
    st.switch_page('pages/01_Browse_Animals.py')

if st.button('Schedule an Appointment',
             type='primary',
             use_container_width=True):
    st.switch_page('pages/03_Schedule_Appointment.py')

if st.button('Submit an Application',
             type="primary",
             use_container_width = True):
    st.switch_page('pages/04_Adopter_Application.py')
