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
    response = requests.get(API_URL)
    if response.status_code == 200:
        applications = response.json()
    else: 
        applications = []
        st.error("Failed to fetch application data from the API.")
except requests.exceptions.RequestException as e:
    applications = []
    st.error(f"Error connecting to the API: {str(e)}")

# search bar and filter
search_col, filter_col = st.columns([4, 1]) 
with search_col:
    search_query = st.text_input("🔍 Search", placeholder="Search by adopter name, animal name...")
with filter_col:
    status_filter = st.selectbox("Status", ["All", "Pending", "Under Review", "Approved", "Denied", "Withdrawn", "Completed"])

# apply filters
filtered = applications
if search_query:
    q = search_query.lower()
    filtered = [a for a in filtered if q in a.get("adopter_name", "").lower()
                or q in a.get("animal_name", "").lower()]
if status_filter != "All":
    filtered = [a for a in filtered if a.get("status", "") == status_filter]

st.write(f"**{len(filtered)}** applications found")
st.divider()

# display each application as an expandable row
for app in filtered:
    adopter = app.get("adopter_name", "N/A")
    animal = app.get("animal_name", "N/A")
    species = app.get("species", "")
    status = app.get("status", "N/A")
    
    status_emoji = {
        "Pending": "⏳", "Under Review": "🔍", "Approved": "✅",
        "Denied": "❌", "Withdrawn": "↩️", "Completed": "🎉"
    }.get(status, "📋")

    with st.expander(f"{status_emoji} **{adopter}** → {animal} the {species} — *{status}*"):
        c1, c2 = st.columns(2)
        with c1:
            st.write(f"**Adopter:** {adopter}")
            st.write(f"**Animal:** {animal}")
            st.write(f"**Species:** {species}")
        with c2:
            st.write(f"**Status:** {status_emoji} {status}")
            st.write(f"**Submitted:** {app.get('submission_date', 'N/A')}")
            decision = app.get("decision_date", None)
            st.write(f"**Decision Date:** {decision if decision else 'Pending'}")
        
        notes = app.get("notes", None)
        if notes:
            st.divider()
            st.write(f"**Notes:** {notes}")