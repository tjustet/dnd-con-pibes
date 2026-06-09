<script setup>
const route = useRoute()
const supabase = useSupabaseClient()
const user = useSupabaseUser()

const perfil = ref(null)
const campana = ref(null)
const personajes = ref([])
const cargando = ref(true)

// Modal de Creación
const nuevoPj = ref({
  nombre_pj: '', raza: '', clase: '', nivel: 1, player_email: '',
  fuerza: 10, destreza: 10, constitucion: 10, inteligencia: 10, sabiduria: 10, carisma: 10
})

const calcularModificador = (valor) => {
  const mod = Math.floor((valor - 10) / 2)
  return mod >= 0 ? `+${mod}` : mod
}

const cargarDatos = async () => {
  try {
    // 1. Identificar al usuario
    const { data: authData } = await supabase.auth.getSession()
    if (authData?.session?.user) {
      const { data: profileData } = await supabase.from('profiles').select('*').eq('email', authData.session.user.email).single()
      perfil.value = profileData
    }

    // 2. Traer datos de la campaña actual usando el ID de la URL
    const idCampana = route.params.id
    const { data: campData } = await supabase.from('campaigns').select('*').eq('id', idCampana).single()
    campana.value = campData

    // 3. Traer los personajes de este mundo
    if (campData) {
      const { data: pjData } = await supabase.from('characters').select('*').eq('campaign_id', idCampana)
      personajes.value = pjData || []
    }
  } catch (error) {
    console.error("Error cargando la campaña:", error)
  } finally {
    cargando.value = false
  }
}

const crearPersonaje = async () => {
  if (!nuevoPj.value.nombre_pj || !nuevoPj.value.player_email) return
  
  const { error } = await supabase.from('characters').insert([{
    campaign_id: route.params.id,
    nombre_pj: nuevoPj.value.nombre_pj,
    raza: nuevoPj.value.raza,
    clase: nuevoPj.value.clase,
    nivel: nuevoPj.value.nivel,
    player_email: nuevoPj.value.player_email.trim(),
    fuerza: nuevoPj.value.fuerza,
    destreza: nuevoPj.value.destreza,
    constitucion: nuevoPj.value.constitucion,
    inteligencia: nuevoPj.value.inteligencia,
    sabiduria: nuevoPj.value.sabiduria,
    carisma: nuevoPj.value.carisma
  }])

  if (!error) {
    nuevoPj.value = { nombre_pj: '', raza: '', clase: '', nivel: 1, player_email: '', fuerza: 10, destreza: 10, constitucion: 10, inteligencia: 10, sabiduria: 10, carisma: 10 }
    await cargarDatos()
  } else {
    console.error("Error al forjar el héroe:", error)
  }
}

onMounted(() => {
  cargarDatos()
})
</script>

<template>
  <div class="pantalla-campana">
    <div class="filtro-oscuro"></div>

    <div class="contenedor-principal">
      <NuxtLink to="/dashboard" class="btn-volver">← Volver a la Taberna</NuxtLink>

      <div v-if="cargando" class="cargando">Abriendo los mapas del mundo...</div>
      
      <div v-else-if="campana">
        <header class="cabecera-campana panel-glass">
          <h1 class="titulo-mundo">{{ campana.nombre_campanya }}</h1>
          <p class="detalles-mundo">Mundo regido por el DM</p>
          
          <NuxtLink :to="`/personajes/nuevo?campana=${campana.id}`" class="btn-accion-dm mt-4">+ Forjar Nuevo Héroe</NuxtLink>
        </header>

        <h2 class="subtitulo-seccion mt-8">Aventureros en este mundo</h2>
        
        <div v-if="personajes.length > 0" class="grilla-personajes">
          <div v-for="pj in personajes" :key="pj.id" class="tarjeta-pj panel-glass">
            <h3 class="nombre-pj">{{ pj.nombre_pj }}</h3>
            <p class="clase-pj">{{ pj.raza }} - {{ pj.clase }} (Nivel {{ pj.nivel }})</p>
            <p class="email-vinculado">Vinculado a: {{ pj.player_email }}</p>
            
            <div class="mini-stats">
              <div class="stat"><span class="stat-label">FUE</span> {{ pj.fuerza }}</div>
              <div class="stat"><span class="stat-label">DES</span> {{ pj.destreza }}</div>
              <div class="stat"><span class="stat-label">CON</span> {{ pj.constitucion }}</div>
              <div class="stat"><span class="stat-label">INT</span> {{ pj.inteligencia }}</div>
              <div class="stat"><span class="stat-label">SAB</span> {{ pj.sabiduria }}</div>
              <div class="stat"><span class="stat-label">CAR</span> {{ pj.carisma }}</div>
            </div>

            <NuxtLink :to="`/personajes/${pj.id}`" class="btn-entrar-ficha">Abrir Ficha Interactiva</NuxtLink>
          </div>
        </div>
        <div v-else class="vacio panel-glass">
          La taberna está vacía. El DM debe crear personajes y asignarles correos.
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@700&display=swap');

.pantalla-campana { min-height: 100vh; background-image: url('https://images.unsplash.com/photo-1605806616949-1e87b487cb2a?q=80&w=1920&auto=format&fit=crop'); background-size: cover; background-position: center; background-attachment: fixed; position: relative; color: #e2e8f0; }
.filtro-oscuro { position: absolute; top: 0; left: 0; width: 100%; height: 100%; background: rgba(9, 5, 14, 0.85); pointer-events: none; z-index: 0; }
.contenedor-principal { position: relative; z-index: 10; max-width: 1200px; margin: 0 auto; padding: 2rem; }

.panel-glass { background: rgba(15, 23, 42, 0.7); backdrop-filter: blur(16px); border: 1px solid rgba(255, 255, 255, 0.1); box-shadow: 0 10px 30px rgba(0,0,0,0.5); border-radius: 12px; padding: 2rem; }

.btn-volver { color: #94a3b8; text-decoration: none; display: inline-block; margin-bottom: 2rem; font-weight: bold; transition: color 0.2s; }
.btn-volver:hover { color: #facc15; }

.cabecera-campana { text-align: center; border-top: 4px solid #facc15; }
.titulo-mundo { font-family: 'Cinzel', serif; font-size: 3rem; margin: 0; color: #fde047; text-shadow: 0 4px 10px rgba(0,0,0,0.8); }
.detalles-mundo { color: #a78bfa; font-size: 1.2rem; font-style: italic; }

.subtitulo-seccion { font-family: 'Cinzel', serif; font-size: 2rem; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 0.5rem; margin-bottom: 1.5rem; }
.mt-4 { margin-top: 1rem; } .mt-6 { margin-top: 1.5rem; } .mt-8 { margin-top: 2rem; }

.btn-accion-dm { background: linear-gradient(135deg, #b45309, #78350f); color: white; border: 1px solid #d97706; padding: 0.8rem 1.5rem; border-radius: 6px; cursor: pointer; font-weight: bold; transition: all 0.2s; font-size: 1rem; }
.btn-accion-dm:hover { background: linear-gradient(135deg, #d97706, #92400e); transform: translateY(-2px); }

/* Personajes */
.grilla-personajes { display: grid; grid-template-columns: repeat(auto-fill, minmax(350px, 1fr)); gap: 1.5rem; }
.tarjeta-pj { border-top: 3px solid #3b82f6; transition: transform 0.2s; }
.tarjeta-pj:hover { transform: translateY(-5px); border-color: #60a5fa; }
.nombre-pj { font-family: 'Cinzel', serif; font-size: 1.5rem; margin: 0 0 0.5rem 0; color: #bfdbfe; }
.clase-pj { color: #94a3b8; margin: 0; }
.email-vinculado { color: #10b981; font-size: 0.85rem; font-style: italic; margin-top: 0.5rem; margin-bottom: 1.5rem; }

.mini-stats { display: flex; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 1.5rem; }
.stat { background: rgba(0,0,0,0.4); border: 1px solid #475569; padding: 0.3rem 0.6rem; border-radius: 4px; font-weight: bold; }
.stat-label { color: #facc15; font-size: 0.8rem; margin-right: 0.3rem; }

.btn-entrar-ficha { display: block; text-align: center; background: #1e3a8a; color: white; padding: 0.8rem; border-radius: 6px; text-decoration: none; font-weight: bold; transition: background 0.2s; }
.btn-entrar-ficha:hover { background: #2563eb; }

/* Modal */
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.85); display: flex; align-items: center; justify-content: center; z-index: 50; }
.modal-card { width: 100%; max-width: 600px; max-height: 90vh; overflow-y: auto; border: 1px solid #d97706; }
.scroll-modal::-webkit-scrollbar { width: 8px; } .scroll-modal::-webkit-scrollbar-thumb { background: #b45309; border-radius: 4px; }
.titulo-dorado { font-family: 'Cinzel', serif; color: #fde047; font-size: 1.5rem; border-bottom: 1px solid rgba(253, 224, 71, 0.3); padding-bottom: 0.5rem; margin-bottom: 1rem; margin-top: 0; }

.seccion-form { margin-bottom: 1rem; }
.seccion-form label { display: block; color: #cbd5e1; font-size: 0.9rem; margin-bottom: 0.3rem; }
.input-magico { width: 100%; background: rgba(0,0,0,0.5); border: 1px solid #64748b; padding: 0.8rem; color: white; border-radius: 6px; box-sizing: border-box; }
.input-magico:focus { outline: none; border-color: #facc15; }

.grid-2-col { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.grid-3-col { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; }

.stat-input-box { background: rgba(0,0,0,0.3); border: 1px solid #475569; padding: 0.8rem; border-radius: 6px; text-align: center; position: relative; }
.stat-input-box label { display: block; color: #94a3b8; font-size: 0.8rem; font-weight: bold; margin-bottom: 0.5rem; text-transform: uppercase; }
.input-stat { width: 60px; text-align: center; background: transparent; border: none; border-bottom: 2px solid #facc15; color: white; font-size: 1.5rem; font-weight: bold; padding: 0.2rem; }
.input-stat:focus { outline: none; border-color: #ef4444; }
.mod-preview { position: absolute; top: -10px; right: -10px; background: #b45309; color: white; width: 30px; height: 30px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 0.9rem; border: 2px solid #fde047; }

.acciones { display: flex; justify-content: flex-end; gap: 1rem; }
.btn-cancelar { background: transparent; color: #94a3b8; border: none; cursor: pointer; font-weight: bold; }
.btn-cancelar:hover { color: white; }
</style>