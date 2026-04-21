import logging
logger = logging.getLogger(__name__)

import streamlit as st
from modules.nav import SideBarLinks

st.set_page_config(layout='wide')

# Show appropriate sidebar links for the role of the currently logged in user
SideBarLinks()

st.title(f"Welcome Shelter Staff, {st.session_state['first_name']}.")
st.write('### What would you like to do today?')

if st.button('View Current Animals At Shelter',
             type='primary',
             use_container_width=True):
    st.switch_page('pages/31_Current_Animals.py')

if st.button('View Adoption Applications',
             type='primary',
             use_container_width=True):
    st.switch_page('pages/32_Adoption_Applications.py')

if st.button('View Animal Medical Records',
             type='primary',
             use_container_width=True):
    st.switch_page('pages/33_Medical_Records.py')

if st.button('View Foster Placements',
             type='primary',
             use_container_width=True):
    st.switch_page('pages/35_Foster_Placements.py')



