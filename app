import streamlit as st
import pandas as pd
import googlemaps
from datetime import datetime
import io 

# Configuração da página
st.set_page_config(page_title="Lead Finder - Google Maps", layout="wide")

# Título do aplicativo
st.title("🛍️ Lead Finder - Google Maps")
st.markdown("""
Extração de informações de empresas do Google Maps para captação de leads.
""")

# Sidebar com configurações
with st.sidebar:
    st.header("🔑 Configurações")
    api_key = st.text_input("AIzaSyAXQNMhXJvbgv_PFzYATKubrUMs9LkUQto", type="password")
    st.markdown("""
    ### Como usar:
    1. Obtenha uma API Key do [Google Cloud Platform](https://console.cloud.google.com/)
    2. Ative as APIs: **Places API** e **Maps JavaScript API**
    3. Cole sua chave acima
    4. Faça sua pesquisa
    """)

# Função para buscar lugares
def search_places(query, location, radius, api_key, num_results=20):
    gmaps = googlemaps.Client(key=api_key)
    
    try:
        # Busca por texto
        places_result = gmaps.places(query=query, location=location, radius=radius)
        
        results = []
        for place in places_result['results'][:num_results]:
            # Pega detalhes adicionais
            place_details = gmaps.place(place['place_id'], fields=['name', 'formatted_address', 'formatted_phone_number', 'website', 'rating', 'user_ratings_total'])
            
            # Extrai informações
            name = place_details['result'].get('name', 'N/A')
            address = place_details['result'].get('formatted_address', 'N/A')
            phone = place_details['result'].get('formatted_phone_number', 'N/A')
            website = place_details['result'].get('website', 'N/A')
            rating = place_details['result'].get('rating', 'N/A')
            reviews = place_details['result'].get('user_ratings_total', 'N/A')
            
            # Tenta extrair email do website (simplificado)
            email = 'N/A'
            if website != 'N/A':
                if 'contact' in website.lower():
                    email = f"info@{website.split('//')[-1].split('/')[0]}"
                else:
                    email = f"contact@{website.split('//')[-1].split('/')[0]}"
            
            results.append({
                'Nome': name,
                'Endereço': address,
                'Telefone': phone,
                'Website': website,
                'E-mail': email,
                'Avaliação': rating,
                'Nº de Avaliações': reviews,
                'Place ID': place['place_id']
            })
        
        return pd.DataFrame(results)
    
    except Exception as e:
        st.error(f"Erro na busca: {str(e)}")
        return pd.DataFrame()

# Formulário de pesquisa
with st.form("search_form"):
    st.header("🔍 Pesquisa de Leads")
    col1, col2, col3 = st.columns(3)
    
    with col1:
        query = st.text_input("Termo de busca (ex: restaurante, loja de roupas)", "restaurante")
    with col2:
        location = st.text_input("Localização (cidade, endereço ou coordenadas)", "São Paulo, SP")
    with col3:
        radius = st.slider("Raio de busca (metros)", 500, 50000, 5000)
    
    num_results = st.slider("Número máximo de resultados", 5, 100, 20)
    
    submitted = st.form_submit_button("Buscar Leads")
    
    if submitted and not api_key:
        st.warning("Por favor, insira sua API Key do Google Maps")

# Processamento dos resultados
if submitted and api_key:
    st.info(f"Buscando por '{query}' em '{location}' (raio: {radius}m)...")
    
    with st.spinner("Procurando informações no Google Maps..."):
        df = search_places(query, location, radius, api_key, num_results)
        
        if not df.empty:
            st.success(f"Encontrados {len(df)} resultados!")
            
            # Mostra os dados
            st.dataframe(df)
            
            # Gera Excel para download
            output = io.BytesIO()
            with pd.ExcelWriter(output, engine='xlsxwriter') as writer:
                df.to_excel(writer, index=False, sheet_name='Leads')
                writer.save()
            
            st.download_button(
                label="📥 Baixar em Excel",
                data=output.getvalue(),
                file_name=f"leads_{query}_{datetime.now().strftime('%Y%m%d')}.xlsx",
                mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            )
        else:
            st.warning("Nenhum resultado encontrado. Tente ajustar os parâmetros da busca.")
