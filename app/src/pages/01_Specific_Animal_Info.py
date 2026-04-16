import logging
logger = logging.getLogger(__name__)
import pandas as pd
import streamlit as st
import world_bank_data as wb
import matplotlib.pyplot as plt
import numpy as np
import plotly.express as px
import requests
from modules.nav import SideBarLinks

API = 'http://localhost:4000'

st.set_page_config(layout='wide')

# Call the SideBarLinks from the nav module in the modules directory
SideBarLinks()
st.sidebar.header("Filter")
species_filter = st.sidebar.multiselect("Species", ["Dog", "Cat", "Rabbit", "Other"])
breed_filter = st.sidebar.multiselect("Breed", ["Golden Retriever", "Labrador Retriever", "German Shepherd", "Siamese Cat", "Persian Cat"])
age_filter = st.sidebar.slider("Age", 0, 20, (0, 20))
size_filter = st.sidebar.multiselect("Size", ["Small", "Midsize", "Large"])

# set the header of the page
st.header('Discover the Animals')
st.write(f"### Hi, {st.session_state['first_name']}")

search = st.text_input("Search", placeholder = "Search by breed")


params = {}
if species_filter:
    params['species'] = species_filter
if breed_filter:
    params['breed'] = breed_filter


try:
    response = requests.get(f'{API}/', params=params)
    animals = response.json()
except Exception as e:
    st.error(f"Could not load animals: {e}")
    animals = []


if search:
    animals = [a for a in animals if search.lower() in a['name'].lower()]

if not animals:
    st.info("No animals found matching these filters")
else:
    cols = st.columns(4)
    for i, animal in enumerate(animals):
        with cols[i%4]:
            st.write(f"**{animal['name']}**")
            st.write(f"Species: {animal['species']}")
            st.write(f"Breed: {animal['breed']}")
            st.write(f"Age: {animal['age_months']//12} years {animal['age_months']%12} months")
            st.write(f"Status: {animal['status']}")
            if st.button("View Profile", key = f"btn_{animal['animal_id']}"):
                st.session_state['selected_animal_id'] = animal['animal_id']
                st.switch_page('pages/02_Animal_Profile.py')




