import logging
logger = logging.getLogger(__name__)

import streamlit as st 
import requests 
from modules.nav import SideBarLinks

st.set_page_config(layout='wide')
SideBarLinks()

st.title("📋 PawMatch: Adoption Applications")

# -- API endpoint for applications ---
API_URL = "http://web-api:4000/adopters/applications"

try: 
    reponse = requests.get(API_URL)
    if reponse.status_code == 200:
        applications = reponse.json()
    
    else: 
        applications = []
        st.error("Failed to fetch application data from the API.")

except requests.exceptions.RequestException as e:
    applications = []
    st.error(f"Error connecting to the API: {str(e)}")

# search bar and filter 
search_col, filter_col = st.columns([4, 1]) 
with search_col:
    search_query = st.text_input("🔍 Search", placeholder="Type to start searching...")
with filter_col:
    status_filter = st.selectbox("Status", ['All', 'Pending', 'Under Review', 'Approved',
                         'Denied', 'Withdrawn', 'Completed'])

# apply filters 
filtered = applications 
if search_query:
    q = search_query.lower()
    filtered = [a for a in filtered if q in a.get("adopter_name", "").lower()
                or q in a.get("animal_name", "").lower()
                or q in a.get("status", "").lower()]
if status_filter != "All":
    filtered = [a for a in filtered if a.get("status", "").lower() == status_filter.lower()]

st.write(f"**{len(filtered)}** applications found")

# list of applications
for app in filtered:
    with st.container(border=True):
        col1, col2, col3, col4 = st.columns([2, 2, 2, 1])
        
        with col1:
            st.write(f"**From:** {app.get('adopter_name', 'N/A')}")
        with col2:
            st.write(f"**For:** {app.get('animal_name', 'N/A')}")
        with col3:
            st.write(f"**Date:** {app.get('submission_date', 'N/A')}")
        with col4:
            if st.button("Click for more info", key=f"app_{app.get('application_id', '')}"):
                st.session_state["selected_application_id"] = app.get("application_id")
                st.switch_page("pages/35_Application_Details.py")

                