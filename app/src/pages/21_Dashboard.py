import logging
logger = logging.getLogger(__name__)

import streamlit as st
from modules.nav import SideBarLinks
import requests
import pandas as pd

st.set_page_config(layout='wide')

SideBarLinks()

st.title('Animal Dashboard')
st.write('Live overview of all animals currently in the shelter')

try:
    response = requests.get('http://web-api:4000/analytics/dashboard')
    data = response.json()


    # Top summary metrics
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric('Total Animals', data['total_animals'])
    with col2:
        st.metric('Adopted This Month', data['adopted_this_month'])
    with col3:
        st.metric('Open Applications', data['open_applications'])

    st.divider()

    # Status breakdown
    st.subheader('Animals by Status')
    status_df = pd.DataFrame(data['status_breakdown'])
    st.dataframe(status_df, use_container_width=True)

    st.divider()

    # Longest stays
    st.subheader('Top 10 Longest Stays')
    stays_df = pd.DataFrame(data['longest_stays'])
    st.dataframe(stays_df, use_container_width=True)

except Exception as e:
    st.error(f'Could not load dashboard data. Is the API running? Error: {e}')