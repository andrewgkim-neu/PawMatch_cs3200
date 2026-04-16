import logging
logger = logging.getLogger(__name__)

import streamlit as st
from modules.nav import SideBarLinks

st.set_page_config(layout='wide')

SideBarLinks()

st.title('Data Analyst Home Page')
st.write('### What would you like to do today?')

if st.button('View Live Dashboard',
             type='primary',
             use_container_width=True):
    st.switch_page('pages/21_Dashboard.py')

if st.button('Manage Reports',
             type='primary',
             use_container_width=True):
    st.switch_page('pages/22_Report.py')

if st.button('View Adoption Trends',
             type='primary',
             use_container_width=True):
    st.switch_page('pages/23_Adoption_Trends.py')

    