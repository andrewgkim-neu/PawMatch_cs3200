import logging
logger = logging.getLogger(__name__)
import streamlit as st
import requests
from modules.nav import SideBarLinks

API = 'http://web-api:4000/animals/'

st.set_page_config(layout='wide')

# Call the SideBarLinks from the nav module in the modules directory
SideBarLinks()
st.sidebar.header("Filter")
species_filter = st.sidebar.multiselect("Species", ["Dog", "Cat", "Rabbit", "Other"])
breed_filter = st.sidebar.multiselect("Breed", ["Golden Retriever", "Labrador Retriever", "German Shepherd", "Siamese Cat", "Persian Cat"])
age_filter = st.sidebar.slider("Age", 0, 20, (0, 20))
size_filter = st.sidebar.multiselect("Size", ["Small", "Medium", "Large"])

# set the header of the page
st.title('Discover the Animals')
st.write(f"### Hi, {st.session_state['first_name']}")

search = st.text_input("Search", placeholder = "Search by breed")


params = {}
if species_filter:
    params['species'] = species_filter
if breed_filter:
    params['breed'] = breed_filter


try:
    response = requests.get(API)
    if response.status_code == 200:
        animals = response.json()
    
    else: 
        animals = []
        st.error("Failed to fetch animal data from the API.")


except requests.exceptions.RequestException as e:
    animals = []
    st.error(f"Error connecting to the API: {str(e)}")

filtered = animals

if search: 
    q = search.lower()
    filtered = [a for a in filtered if q in a.get('name', '').lower() or q in a.get('breed', '').lower()]

if species_filter:
    filtered = [a for a in filtered if a.get('species') in species_filter]

if breed_filter:
    filtered = [a for a in filtered if a.get('breed') in breed_filter]

if size_filter:
    filtered = [a for a in filtered if a.get('size') in size_filter]

filtered = [
    a for a in filtered
    if age_filter[0] <= (a.get('age_months', 0)//12) <= age_filter[1]
]

st.write(f"**{len(filtered)}** animals found")

if not filtered:
    st.info("No animals found matching these filters")
else:
    cols_per_row = 3
    for i in range(0, len(filtered), cols_per_row):
        cols = st.columns(cols_per_row)
        for j, col in enumerate(cols):
            if i + j < len(filtered):
                animal = filtered[i + j]
                with col:
                    with st.container(border=True):
                        st.image("assets/animal.png", use_container_width=True)
                        st.subheader(animal.get("name", "Unknown"))
                        st.write(f"**Species:** {animal.get('species', 'N/A')}")
                        st.write(f"**Breed:** {animal.get('breed', 'N/A')}")
                        age_months = animal.get('age_months', 0)
                        st.write(f"**Age:** {age_months // 12} years {age_months % 12} months")
                        st.write(f"**Size:** {animal.get('size', 'N/A')}")
                        st.write(f"**Status:** {animal.get('status', 'N/A')}")
                        if st.button("View Profile", type="primary", key=f"btn_{animal.get('animal_id', i+j)}"):
                            st.session_state['selected_animal_id'] = animal.get('animal_id')
                            st.switch_page('pages/02_Pet_Profile.py')

