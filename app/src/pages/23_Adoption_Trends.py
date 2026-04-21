import logging
logger = logging.getLogger(__name__)

import streamlit as st
from modules.nav import SideBarLinks
import requests
import pandas as pd

st.set_page_config(layout='wide')
SideBarLinks()

st.title('Adoption Trends & Application Funnel')
st.write('Explore time-to-adoption trends and application status breakdown.')

BASE_URL = 'http://web-api:4000/analytics'

st.subheader('Time-to-Adoption Trends')

col1, col2 = st.columns(2)
with col1:
    species_filter = st.selectbox('Filter by Species', ['All', 'Dog', 'Cat', 'Rabbit', 'Bird', 'Other'])
with col2:
    breed_filter = st.text_input('Filter by Breed (optional)')

if st.button('Search Trends', type='primary', use_container_width=True):
    try:
        params = {}
        if species_filter != 'All':
            params['species'] = species_filter
        if breed_filter:
            params['breed'] = breed_filter

        response = requests.get(f'{BASE_URL}/adoption-trends', params=params)
        trends = response.json()

        if trends:
            df = pd.DataFrame(trends)

            # Rename by actual API key names instead of position
            df = df.rename(columns={
                'species':         'Species',
                'breed':           'Breed',
                'year':            'Year',
                'month':           'Month',
                'total_adoptions': 'Total Adoptions',
                'avg_days_to_adopt': 'Avg Days to Adopt'
            })

            st.dataframe(df, use_container_width=True)

            st.divider()

            st.write('#### Avg Days to Adopt Over Time')
            df['Period'] = df['Year'].astype(str) + '-' + df['Month'].astype(str).str.zfill(2)
            df['Avg Days to Adopt'] = pd.to_numeric(df['Avg Days to Adopt'], errors='coerce')
            chart_df = df.groupby('Period')['Avg Days to Adopt'].mean().sort_index()
            st.line_chart(chart_df)

        else:
            st.info('No adoption trend data found for those filters.')

    except Exception as e:
        st.error(f'Could not load adoption trends. Error: {e}')

st.divider()

st.subheader('Application Funnel Breakdown')
st.write('See where prospective adopters are dropping off in the process.')

try:
    response = requests.get(f'{BASE_URL}/application-funnel')
    funnel = response.json()

    if funnel:
        col1, col2 = st.columns(2)

        with col1:
            funnel_df = pd.DataFrame(funnel)

            # Rename by actual API key names instead of position
            funnel_df = funnel_df.rename(columns={
                'status': 'Status',
                'total':  'Total'
            })

            st.dataframe(funnel_df, use_container_width=True)

        with col2:
            st.write('#### Applications by Status')
            chart_df = funnel_df.set_index('Status')
            st.bar_chart(chart_df)

    else:
        st.info('No application data found.')

except Exception as e:
    st.error(f'Could not load application funnel. Error: {e}')