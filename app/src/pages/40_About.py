import logging
logger = logging.getLogger(__name__)

import streamlit as st 
import requests 
from modules.nav import SideBarLinks

st.set_page_config(layout='wide')
SideBarLinks()

st.title("# About this App")

st.markdown(
    """
    Every year, millions of shelter animals may never find a home — not because they aren't wanted, 
    but because shelters often rely on outdated tools like paper forms, spreadsheets, and whiteboards. 
    Medical histories get misplaced, foster updates are lost, and adoption applications pile up with no 
    easy way to track them.

    **PawMatch** is a data-driven Pet Adoption System designed for a single shelter to manage its 
    operations in one place. It tracks every animal from their first day at the shelter to their forever 
    home — managing pet profiles, medical records, and adoption applications so staff can stay organized 
    and make better decisions for every animal under their care.
    """
)

st.subheader("Built For")
c1, c2, c3, c4 = st.columns(4)
with c1:
    st.write("🐶 **Adopting Families**")
    st.write("Search animals, view profiles, and submit applications.")
with c2:
    st.write("💼 **Shelter Staff**")
    st.write("Track animals, manage fosters, and review applications in real time.")
with c3:
    st.write("📊 **Data Analysts**")
    st.write("Query structured data to uncover trends and improve outcomes.")
with c4:
    st.write("🔧 **System Admins**")
    st.write("Manage users, animals, and system-wide settings.")

st.divider()
st.write("*Because every animal deserves a fair chance at finding their perfect home.*")

# Add a button to return to home page
if st.button("Return to Home", type="primary"):
    st.switch_page("Home.py")
