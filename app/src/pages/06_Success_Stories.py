import logging
logger = logging.getLogger(__name__)
import streamlit as st
import requests
from modules.nav import SideBarLinks
from datetime import datetime

API = 'http://web-api:4000'


st.set_page_config(layout='wide')
SideBarLinks()

st.title("Success Stories")
st.caption("Stories and reviews from our past adopters.")


# filters
col1, col2, col3 = st.columns(3)
with col1:
    species_filter = st.selectbox("Species", ["All", "Dog", "Cat", "Rabbit", "Other"])
with col2:
    rating_filter = st.selectbox("Rating", ["All", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"])
with col3:
    sort_by = st.selectbox("Sort by", ["Highest rated", "Newest first", "Oldest first"])




# params
rating_map = {
    "All": (None, None),
    "1": (1, 1),
    "2": (2, 2),
    "3": (3, 3),
    "4": (4, 4),
    "5": (5, 5),
    "6": (6, 6),
    "7": (7, 7),
    "8": (8, 8),
    "9": (9, 9),
    "10": (10, 10),
}

sort_map = {
    "Newest first": "newest",
    "Oldest first": "oldest",
    "Highest rated": "rating"
}

params = {"sort": sort_map[sort_by]}

if species_filter != "All":
    params['species'] = species_filter

rating_min, rating_max = rating_map[rating_filter]
if rating_min:
    params["rating_min"] = rating_min
    params["rating_max"] = rating_max 



# pages
if "page" not in st.session_state:
    st.session_state.page = 1

params["page"] = st.session_state.page
params["per_page"] = 5


# get stories
resp = requests.get(f"{API}/success_story", params=params)
if resp.status_code != 200:
    st.error("Could not load stories.")
    st.stop()

data = resp.json()
content = data.get("stories", [])
total_pages = data.get("total_pages", 1)

if not content:
    st.info("No posts match your filters.")
else:
    for story in content:
        with st.container(border=True):
            header_col, rating_col = st.columns([4, 1])
            with header_col:
                st.caption(f"Story #{story['story_id']}. Posted {datetime.strptime(story['posted_at'], '%a, %d %b %Y %H:%M:%S %Z').strftime('%b %d, %Y')}")
            with rating_col:
                rating = story["rating"]
                color = "green" if rating >= 8 else "orange" if rating >= 5 else "red"
                st.markdown(f"<span style= 'color: {color}; font-weight: 600; font-size: 1.1rem'> {rating}/10</span>",
                            unsafe_allow_html=True)
                
            st.write(story["content"])

# pages
st.divider()

p_col1, p_col2, p_col3 = st.columns([1, 2, 1])
with p_col1:
    if st.button("Previous", disabled = st.session_state.page <= 1):
        st.session_state.page -= 1
        st.rerun()
with p_col2:
    st.markdown(f"<p style = 'text-align: center; color: gray;'> Page {st.session_state.page} of {total_pages}</p>",
                unsafe_allow_html = True)
with p_col3:
    if st.button("Next", disabled = st.session_state.page >= total_pages):
        st.session_state.page += 1
        st.rerun()


            

