import logging
logger = logging.getLogger(__name__)

import streamlit as st
from modules.nav import SideBarLinks
import requests
import pandas as pd

st.set_page_config(layout='wide')
SideBarLinks()

st.title('Report Manager')
st.write('Save templates, generate monthly reports, and manage existing reports')

BASE_URL = 'http://web-api:4000/analytics'

# Saved report templates
st.subheader('Saved Report Templates')

try:
    response = requests.get(f'{BASE_URL}/reports/templates')
    templates = response.json()

    if templates:
        df = pd.DataFrame(templates)
        st.dataframe(df, use_container_width=True)

        st.divider()

        # Archive or delete a template
        st.write('#### Manage a Template')
        template_ids = [t['template_id'] for t in templates]
        selected_id = st.selectbox('Select a Template ID', template_ids)

        col1, col2 = st.columns(2)

        with col1:
            if st.button('Archive Template', use_container_width=True):
                try:
                    r = requests.delete(f'{BASE_URL}/reports/templates/{selected_id}')
                    if r.status_code == 200:
                        st.success('Template archived successfully!')
                    else:
                        st.error(f'Error: {r.json()}')
                except Exception as e:
                    st.error(f'Error: {e}')

        with col2:
            if st.button('Permanently Delete Template', use_container_width=True):
                try:
                    r = requests.delete(f'{BASE_URL}/reports/templates/{selected_id}?permanent=true')
                    if r.status_code == 200:
                        st.success('Template permanently deleted!')
                    else:
                        st.error(f'Error: {r.json()}')
                except Exception as e:
                    st.error(f'Error: {e}')

    else:
        st.info('No saved templates yet.')

except Exception as e:
    st.error(f'Could not load templates. Error: {e}')

st.divider()

#Create new report template
st.subheader('Create a New Report Template')

with st.form('create_template_form'):
    template_name = st.text_input('Template Name')
    export_format = st.selectbox('Export Format', ['PDF', 'CSV', 'Excel'])
    metric_included = st.multiselect('Metric Included', [
    'Total Adopted',
    'Average Days to Adopt',
    'Average Length of Stay',
    'Species Breakdown',
    'Intake Count'
])
    date_range_start = st.date_input('Date Range Start')
    date_range_end = st.date_input('Date Range End')

    submitted = st.form_submit_button('Save Template', use_container_width=True)

    if submitted:
        if not template_name:
            st.error('Template name is required!')
        else:
            try:
                payload = {
                    'template_name': template_name,
                    'export_format': export_format,
                    'metric_included': metric_included,
                    'date_range_start': str(date_range_start),
                    'date_range_end': str(date_range_end)
                }
                r = requests.post(f'{BASE_URL}/reports/templates', json=payload)
                if r.status_code == 201:
                    st.success('Template saved successfully!')
                else:
                    st.error(f'Error: {r.json()}')
            except Exception as e:
                st.error(f'Error: {e}')

st.divider()

#Generate monthly report
st.subheader('Generate Monthly Report')

with st.form('generate_report_form'):
    report_month = st.date_input('Report Month')

    # Let user pick a template if they want
    try:
        template_response = requests.get(f'{BASE_URL}/reports/templates')
        template_list = template_response.json()
        template_options = {t['template_name']: t['template_id'] for t in template_list}
        selected_template = st.selectbox('Use Template (optional)', ['None'] + list(template_options.keys()))
    except:
        template_options = {}
        selected_template = 'None'

    generate_submitted = st.form_submit_button('Generate Report', use_container_width=True)

    if generate_submitted:
        try:
            payload = {
                'report_month': str(report_month),
                'template_id': template_options.get(selected_template) if selected_template != 'None' else None
            }
            r = requests.post(f'{BASE_URL}/reports/monthly', json=payload)
            if r.status_code == 201:
                st.success('Monthly report generated!')
                result = r.json()
                stats = result.get('stats', {})
                col1, col2, col3 = st.columns(3)
                with col1:
                    st.metric('Total Adopted', stats.get('total_adopted', 0))
                with col2:
                    st.metric('Avg Days to Adopt', round(stats.get('avg_days_to_adopt') or 0, 1))
                with col3:
                    st.metric('Avg Length of Stay', round(stats.get('avg_length_of_stay') or 0, 1))
            else:
                st.error(f'Error: {r.json()}')
        except Exception as e:
            st.error(f'Error: {e}')

st.divider()

#View past monthly reports
st.subheader('Past Monthly Reports')

try:
    r = requests.get(f'{BASE_URL}/reports/monthly')
    reports = r.json()

    if reports:
        reports_df = pd.DataFrame(reports)
        st.dataframe(reports_df, use_container_width=True)
    else:
        st.info('No monthly reports generated yet.')

except Exception as e:
    st.error(f'Could not load monthly reports. Error: {e}')