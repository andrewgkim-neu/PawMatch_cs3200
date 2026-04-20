import logging
logger = logging.getLogger(__name__)
import streamlit as st
import requests
from modules.nav import SideBarLinks
from itertools import groupby

API = 'http://web-api:4000'

st.set_page_config(layout='wide')
SideBarLinks()


# title
st.title("Compatibility Quiz")
st.write(f"Hi, {st.session_state.get('first_name', 'adopter')}!")
st.write("Answer a few questions below, and we'll match you with an animal in the shelter.")

st.divider()


# quiz
if not st.session_state.get('quiz_submitted'):
    with st.form('compatibility_quiz_form'):
        species_pref = st.selectbox("What kind of animal are you looking for?",
                                        ["No Preference", "Dog", "Cat", "Rabbit", "Other"])
        size_pref = st.selectbox("What size are you looking for?",
                                    ["No Preference", "Small", "Midsize", "Large"])
        energy_pref = st.selectbox("What energy level fits your lifestyle?",
                                    ["No Preference", "Low", "Medium", "High"])
        age_pref = st.selectbox("What age do you prefer?",
                                    ["No Preference", "Baby", "Adult", "Senior"])
        
        submitted = st.form_submit_button("Find My Match!", type="primary", use_container_width = True)


# results and score
        if submitted:
            st.session_state['quiz_prefs'] = {
                "species_pref" : species_pref,
                "size_pref" : size_pref,
                "energy_pref" : energy_pref,
                "age_pref" : age_pref
            }
            st.session_state['quiz_submitted'] = True
            st.rerun()


if st.session_state.get('quiz_submitted'):
    prefs = st.session_state['quiz_prefs']
    species_pref = prefs['species_pref']
    size_pref = prefs['size_pref']
    energy_pref = prefs['energy_pref']
    age_pref = prefs['age_pref']

# get animals that are not 'Adopted' or on 'Medical Hold'
    try:
        r = requests.get(f"{API}/animals/")
        animals = r.json() if r.status_code == 200 else []
    except requests.exceptions.RequestException:
        animals = []
        st.error("Error connecting to the API.")

    adoptable_statuses = {"Available", "Fostered", "Pending Adoption"}
    animals = [a for a in animals if a.get("status") in adoptable_statuses]


    def age_range(age_months):
        if age_months < 12:
            return "Baby"
        elif age_months < 96:
            return "Adult"
        else:
            return "Senior"
    

# add score for questions -- all evenly scored
    # if all 'No Preference', will be matched with every animal
    def score_animal(a):
        score = 0
        if species_pref == "No Preference" or a.get('species') == species_pref:
            score +=25
        if size_pref == "No Preference" or a.get('size') == size_pref:
            score += 25
        if energy_pref == "No Preference" or a.get('energy_level') == energy_pref:
            score += 25
        if age_pref == "No Preference" or age_range(a.get('age_months', 0)) == age_pref:
            score += 25
        return score

    scored = sorted([{'score': score_animal(a), **a} for a in animals], key=lambda x: x['score'], reverse = True)


    

# display results
    st.subheader("Your Matches")
    perfect_match = sum(1 for a in scored if a['score'] == 100)
    st.write(f"You matched perfectly with {perfect_match} animal{'s' if perfect_match != 1 else ''}!")

    if not scored:
        st.info("There are currently no available animals that match your preferences.")
    else:
        for score_val, group in groupby(scored, key= lambda x: x['score']):
            group = list(group)
            st.divider()
            st.markdown(f"### {score_val}% Match")
            st.divider()

            cols_per_row = 3
            for i in range(0, len(group), cols_per_row):
                batch = group[i:i + cols_per_row]
                cols = st.columns(cols_per_row)
                for j in range(cols_per_row):
                    if j < len(batch):
                        animal = batch[j]
                        with cols[j]:
                                st.image("assets/animal.png", use_container_width = True)


                                st.subheader(animal.get('name', 'Unknown'))
                                st.write(f"**Species:** {animal.get('species', 'N/A')}")
                                st.write(f"**Breed:** {animal.get('breed', 'N/A')}")
                                age_months = animal.get('age_months', 0)
                                st.write(f"**Age:** {age_months // 12} years {age_months %12} months")
                                st.write(f"**Size:** {animal.get('size', 'N/A')}")
                                
                                status = animal.get('status', 'N/A')
                                if status == 'Available':
                                    st.success(status)
                                elif status in ('Pending Adoption', 'Fostered'):
                                    st.warning(status)
                                else:
                                    st.error(status)
                                
                                if st.button("View Profile", key=f"quiz_btn_{animal.get('animal_id', i+j)}_{score_val}"):
                                    st.session_state['selected_animal_id'] = animal.get('animal_id')
                                    st.switch_page('pages/02_Pet_Profile.py')



    if st.button("Take a New Quiz", type = "primary", use_container_width=True):
        st.session_state.pop('quiz_submitted', None)
        st.session_state.pop('quiz_prefs', None)
        st.rerun()