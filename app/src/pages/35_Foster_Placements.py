import logging
logger = logging.getLogger(__name__)

import streamlit as st 
import requests 
from modules.nav import SideBarLinks

st.set_page_config(layout='wide')
SideBarLinks()

st.title("🏠 PawMatch: Foster Placements")

# -- API endpoint ---
API_URL = "http://web-api:4000/foster_placements/"

try: 
    response = requests.get(API_URL)
    if response.status_code == 200:
        placements = response.json()
    else: 
        placements = []
        st.error("Failed to fetch foster placement data from the API.")
except requests.exceptions.RequestException as e:
    placements = []
    st.error(f"Error connecting to the API: {str(e)}")



# search bar and filter
search_col, filter_col = st.columns([4, 1]) 
with search_col:
    search_query = st.text_input("🔍 Search", placeholder="Search by foster name or animal name...")
with filter_col:
    status_filter = st.selectbox("Status", ["All", "Active", "Completed"])

# apply filters
filtered = placements
if search_query:
    q = search_query.lower()
    filtered = [p for p in filtered if q in p.get("foster_name", "").lower()
                or q in p.get("animal_name", "").lower()]
if status_filter == "Active":
    filtered = [p for p in filtered if not p.get("end_date")]
elif status_filter == "Completed":
    filtered = [p for p in filtered if p.get("end_date")]

st.write(f"**{len(filtered)}** placements found")
st.divider()

# display each placement as an expandable row
for p in filtered:
    foster = p.get("foster_name", "N/A")
    animal = p.get("animal_name", "N/A")
    species = p.get("species", "")
    start = p.get("start_date", "N/A")
    end = p.get("end_date", None)
    
    active = "🟢 Active" if not end else "⚪ Completed"

    with st.expander(f"{active} — **{animal}** the {species} → fostered by **{foster}** (started {start})"):
        c1, c2 = st.columns(2)
        with c1:
            st.write(f"**Foster Parent:** {foster}")
            st.write(f"**Animal:** {animal} ({species})")
            st.write(f"**Start Date:** {start}")
            st.write(f"**End Date:** {end if end else '—  Still in foster'}")
        with c2:
            return_reason = p.get("return_reason", None)
            st.write(f"**Return Reason:** {return_reason if return_reason else 'N/A'}")
        
        st.divider()

        health = p.get("health_notes", None)
        behavior = p.get("behavior_notes", None)
        
        n1, n2 = st.columns(2)
        with n1:
            st.write("**🩺 Health Notes**")
            st.write(health if health else "No health notes recorded.")
        with n2:
            st.write("**🐾 Behavior Notes**")
            st.write(behavior if behavior else "No behavior notes recorded.")