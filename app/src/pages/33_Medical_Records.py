import logging
logger = logging.getLogger(__name__)

import streamlit as st 
import requests 
from modules.nav import SideBarLinks

st.set_page_config(layout='wide')
SideBarLinks()

st.title("💉 PawMatch: Medical Records")

# -- Fetch all animals first ---
API_URL = "http://web-api:4000/animals/"

try: 
    response = requests.get(API_URL)
    if response.status_code == 200:
        animals = response.json()
        # fetch medical records for each animal upfront
        for animal in animals:
            try:
                detail = requests.get(f"{API_URL}{animal.get('animal_id')}")
                if detail.status_code == 200:
                    animal["medical_records"] = detail.json().get("medical_records", [])
                else:
                    animal["medical_records"] = []
            except:
                animal["medical_records"] = []
    else: 
        animals = []
        st.error("Failed to fetch animal data from the API.")
except requests.exceptions.RequestException as e:
    animals = []
    st.error(f"Error connecting to the API: {str(e)}")

# search bar and filter
search_col, filter_col = st.columns([4, 1]) 
with search_col:
    search_query = st.text_input("🔍 Search", placeholder="Search by name, species, or breed...")
with filter_col:
    category_filter = st.selectbox("Record Type", ["All", "Vaccination", "Surgery", "Medication", "Checkup", "Treatment", "Spray/Neuter"])

# filter animals by search
filtered = animals
if search_query:
    q = search_query.lower()
    filtered = [a for a in filtered if q in a.get("name", "").lower()
                or q in a.get("species", "").lower()
                or q in a.get("breed", "").lower()]

# filter by category — only show animals that have records of that type
if category_filter != "All":
    filtered = [a for a in filtered if any(
        r.get("category") == category_filter for r in a.get("medical_records", [])
    )]

st.write(f"**{len(filtered)}** animals found")
st.divider()

# display each animal with expandable medical records
for animal in filtered:
    name = animal.get("name", "Unknown")
    species = animal.get("species", "N/A")
    breed = animal.get("breed", "N/A")
    records = animal.get("medical_records", [])

    # apply category filter to records
    if category_filter != "All":
        records = [r for r in records if r.get("category") == category_filter]

    with st.expander(f"🐾 **{name}** — {species} ({breed})"):
        if records:
            for rec in records:
                with st.container(border=True):
                    c1, c2, c3, c4 = st.columns([1.5, 1.5, 2, 2])
                    with c1:
                        category = rec.get("category", "N/A")
                        emoji = {"Vaccination": "💉", "Surgery": "🏥", "Medication": "💊",
                                 "Checkup": "🩺", "Treatment": "🩹", "Spray/Neuter": "✂️"}.get(category, "📋")
                        st.write(f"**{emoji} {category}**")
                    with c2:
                        st.write(f"**Date:** {rec.get('admin_date', 'N/A')}")
                    with c3:
                        st.write(f"**Practitioner:** {rec.get('practitioner_name', 'N/A')}")
                    with c4:
                        st.write(f"**Notes:** {rec.get('notes', 'N/A')}")
        else:
            st.info("No medical records found for this animal.")