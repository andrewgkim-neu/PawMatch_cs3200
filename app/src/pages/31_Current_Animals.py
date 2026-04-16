import logging
logger = logging.getLogger(__name__)

import streamlit as st 
import requests 
from modules.nav import SideBarLinks

st.set_page_config(layout='wide')
SideBarLinks()

st.title("🐾 PawMatch: Current Animals")

# -- API endpoint for animals ---
API_URL = "http://web-api:4000/animals"

try: 
    reponse = requests.get(API_URL)
    if response.status_code == 200:
        animals = response.json()
    
    else: 
        animals = []
        st.error("Failed to fetch animal data from the API.")

except requests.exceptions.RequestException as e:
    animals = []
    st.error(f"Error connecting to the API: {str(e)}")

# search bar and filter 
with search_col:
    search_query = st.text_input("Search", placeholder="Type to start searching...")
with filter_col:
    status_filter = st.selectbox("Status", ['Available', 'Adopted', 'Pending Adoption', 'Fostered', 'Medical Hold'])

# apply filters 
filtered = animals 
if search_query:
    q = search_query.lower()
    filtered = [a for a in filtered if q in a.get("Name", "").lower()
                or q in a.get("species", "").lower()
                or q in a.get("breed", "").lower()]
if status_filter != "All":
    filtered = [a for a in filtered if a.get("status", "").lower() == status_filter.lower()]

st.write(f"**{len(filtered)}** animals found")

# card grid (3 columns)
cols_per_row = 3
for i in range(0, len(filtered), cols_per_row):
    cols = st.columns(cols_per_row)
    for j, col in enumerate(cols):
        if i + j < len(filtered):
            animal = filtered[i + j]
            with col:
                with st.container(border=True):
                    # Use a placeholder image if no photo URL exists
                    photo = animal.get("assets/animal.png", None)
                    if photo:
                        st.image(photo, use_container_width=True)
                    else:
                        st.image("https://placehold.co/300x200?text=No+Photo", use_container_width=True)

                    st.subheader(animal.get("name", "Unknown"))
                    st.write(f"**Species:** {animal.get('species', 'N/A')}")
                    st.write(f"**Breed:** {animal.get('breed', 'N/A')}")
                    st.write(f"**Status:** {animal.get('status', 'N/A')}")
                    st.write(f"**Flagged:** {animal.get('flagged', 'N/A')}")
                    st.write(f"**Age (Months):** {animal.get('age_months', 'N/A')}")
                    st.write(f"**Intake Date:** {animal.get('intake_date', 'N/A')}")

                    # TODO Button to view full profile (will connect to adopter specific_animal page ?)
                    if st.button("View Details", key=f"view_{animal.get('Animal_ID', i+j)}"):
                        st.session_state["selected_animal_id"] = animal.get("Animal_ID")
                        st.switch_page("pages/34_Animal_Details.py")

                