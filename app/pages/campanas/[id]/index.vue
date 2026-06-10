<script setup>
import { ref, onMounted } from 'vue'

const route = useRoute()
const router = useRouter()
const supabase = useSupabaseClient()

const cargando = ref(true)
const campana = ref({ nombre: 'Cargando campaña...' })
const listaPersonajes = ref([])

const cargarDatosCampana = async () => {
  cargando.value = true
  try {
    // 1. Traer los detalles de la campaña actual
    const { data: campanaData } = await supabase
      .from('campaigns')
      .select('*')
      .eq('id', route.params.id)
      .single()
    
    if (campanaData) {
      campana.value = campanaData
    }

    // 2. Traer solo los personajes que pertenecen a esta campaña
    const { data: personajesData } = await supabase
      .from('characters')
      .select('id, nombre_pj, raza, clase, nivel, player_email, imagen_url')
      .eq('campaign_id', route.params.id)
    
    if (personajesData) {
      listaPersonajes.value = personajesData
    }
  } catch (err) {
    console.error("Error al forjar los datos de la campaña:", err)
  } finally {
    cargando.value = false
  }
}

onMounted(() => {
  cargarDatosCampana()
})
</script>

<template>
  <div class="pantalla-campana">
    <div class="filtro-oscuro"></div>

    <div v-if="cargando" class="cargando-box">
      <span class="texto-cargando">Descifrando pergaminos de la campaña...</span>
    </div>

    <div v-else class="contenedor-principal">
      <div class="header-campana">
        <div class="header-izq">
          <button @click="router.push('../../')" class="btn-regresar">← Volver</button>
          <h1 class="titulo-campana">{{ campana.nombre }}</h1>
          <button @click="router.push(`/campanas/${route.params.id}/dm`)" class="btn-dm-acceso">👁️ Pantalla del DM</button>
        </div>
        <div class="header-der" style="display: flex; gap: 0.8rem; align-items: center;">
          <button class="btn-nuevo" @click="router.push(`/personajes/nuevo?campana=${route.params.id}&tipo=pj`)">
            + Crear Personaje
          </button>
          <button class="btn-nuevo" style="border-color: #ef4444; color: #fca5a5;" @click="router.push(`/personajes/nuevo?campana=${route.params.id}&tipo=npc`)">
            + Crear NPC/Enemigo
          </button>
        </div>
      </div>

      <div class="grilla-personajes">
        <div v-for="pj in listaPersonajes" :key="pj.id" class="tarjeta-pj">
          
          <div class="avatar-zona">
            <img v-if="pj.imagen_url" :src="pj.imagen_url" class="img-avatar" />
            <div v-else class="img-fallback">🛡️</div>
          </div>
          
          <div class="info-zona">
            <h2 class="pj-nombre">{{ pj.nombre_pj || 'Héroe sin nombre' }}</h2>
            <div class="pj-stats">
              <span class="badge-stat">{{ pj.raza || 'Sin Raza' }}</span>
              <span class="badge-stat highlight">{{ pj.clase || 'Sin Clase' }}</span>
              <span class="badge-stat font-mono">Nvl {{ pj.nivel || 1 }}</span>
            </div>
            <div class="pj-mail">
              <i class="fa-regular fa-envelopeIcon"></i> {{ pj.player_email || 'Sin jugador vinculado' }}
            </div>
          </div>
          
          <div class="accion-zona">
            <button @click="router.push(`/personajes/${pj.id}`)" class="btn-abrir-ficha">
              Abrir Ficha ➔
            </button>
          </div>

        </div>
      </div>

      <div v-if="listaPersonajes.length === 0" class="caja-vacia">
        <p class="texto-vacio">No hay héroes asignados a esta campaña todavía. ¡Comenzá creando uno!</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Inter:wght@400;600;700&display=swap');

.pantalla-campana { min-height: 100vh; background-color: #050505; color: #cbd5e1; font-family: 'Inter', sans-serif; position: relative; padding: 2rem 1rem; }
.filtro-oscuro { position: absolute; inset: 0; background: radial-gradient(circle at top, #111 0%, #000 100%); z-index: 0; }
.contenedor-principal { position: relative; z-index: 10; max-width: 1200px; margin: 0 auto; width: 100%; }

/* CARGANDO */
.cargando-box { min-height: 60vh; display: flex; align-items: center; justify-content: center; position: relative; z-index: 10; }
.texto-cargando { font-family: 'Cinzel', serif; font-size: 1.5rem; color: #64748b; text-align: center; }

/* HEADER */
.header-campana { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #1e293b; padding-bottom: 1.2rem; margin-bottom: 2.5rem; gap: 1rem; flex-wrap: wrap; }
.header-izq { display: flex; align-items: center; gap: 1.5rem; }
.btn-regresar { background: transparent; border: 1px solid #334155; color: #94a3b8; padding: 0.4rem 0.8rem; border-radius: 6px; cursor: pointer; font-weight: 600; font-size: 0.85rem; transition: 0.2s; }
.btn-regresar:hover { background: #1e293b; color: white; }
.titulo-campana { font-family: 'Cinzel', serif; font-size: 2.2rem; color: #facc15; margin: 0; line-height: 1.1; }
.btn-nuevo { background: transparent; border: 1px dashed #3b82f6; color: #3b82f6; padding: 0.6rem 1.2rem; border-radius: 6px; cursor: pointer; font-weight: bold; transition: 0.2s; font-size: 0.9rem; }
.btn-nuevo:hover { background: #3b82f6; color: white; box-shadow: 0 0 15px rgba(59, 130, 246, 0.4); }

/* GRILLA DE TARJETAS HORIZONTALES */
.grilla-personajes { display: grid; grid-template-columns: repeat(auto-fill, minmax(500px, 1fr)); gap: 1.5rem; }

@media (max-width: 550px) {
  .grilla-personajes { grid-template-columns: 1fr; }
}

/* LA TARJETA DEL PERSONAJE */
.tarjeta-pj { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 12px; display: flex; align-items: center; padding: 1.2rem; transition: transform 0.2s, border-color 0.2s, box-shadow 0.2s; box-shadow: 0 5px 15px rgba(0,0,0,0.5); position: relative; overflow: hidden; }
.tarjeta-pj:hover { transform: translateY(-3px); border-color: #3b82f6; box-shadow: 0 10px 25px rgba(0,0,0,0.85), 0 0 15px rgba(59,130,246,0.1); }

/* SECCIÓN 1: Avatar (Izquierda) */
.avatar-zona { flex-shrink: 0; width: 85px; height: 85px; margin-right: 1.5rem; }
.img-avatar { width: 100%; height: 100%; object-fit: cover; border-radius: 8px; border: 1px solid #27272a; }
.img-fallback { width: 100%; height: 100%; background: #111; border: 1px dashed #334155; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: 2.2rem; }

/* SECCIÓN 2: Info central */
.info-zona { flex-grow: 1; display: flex; flex-direction: column; justify-content: center; gap: 0.5rem; min-width: 0; }
.pj-nombre { font-family: 'Cinzel', serif; font-size: 1.5rem; color: white; margin: 0; line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.pj-stats { display: flex; gap: 0.5rem; flex-wrap: wrap; }
.badge-stat { background: #141416; color: #94a3b8; font-size: 0.75rem; font-weight: 700; padding: 0.2rem 0.6rem; border-radius: 4px; border: 1px solid #1e293b; text-transform: uppercase; letter-spacing: 0.5px; }
.badge-stat.highlight { color: #facc15; border-color: #b45309; background: rgba(250, 204, 21, 0.03); }
.font-mono { font-family: monospace; }
.pj-mail { font-size: 0.8rem; color: #475569; margin-top: 0.1rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

/* SECCIÓN 3: Botón (Derecha) */
.accion-zona { flex-shrink: 0; padding-left: 1.2rem; border-left: 1px dashed #1e293b; display: flex; align-items: center; height: 70px; margin-left: 1rem; }
.btn-abrir-ficha { background: #1e3a8a; border: 1px solid #3b82f6; color: #bfdbfe; font-family: 'Cinzel', serif; font-weight: bold; font-size: 0.85rem; padding: 0.6rem 1rem; border-radius: 6px; cursor: pointer; transition: all 0.2s; white-space: nowrap; }
.btn-abrir-ficha:hover { background: #2563eb; color: white; transform: scale(1.03); }

/* CAJA VACÍA */
.caja-vacia { background: #0a0a0c; border: 1px dashed #1e293b; border-radius: 12px; padding: 3rem; text-align: center; margin-top: 2rem; }
.texto-vacio { font-style: italic; color: #475569; font-size: 1rem; margin: 0; }

/* RESPONSIVE PARA SMARTPHONES EXTREMOS */
@media (max-width: 480px) {
  .tarjeta-pj { flex-direction: column; text-align: center; gap: 1rem; }
  .avatar-zona { margin-right: 0; }
  .accion-zona { border-left: none; border-top: 1px dashed #1e293b; padding-left: 0; padding-top: 1rem; width: 100%; justify-content: center; height: auto; margin-left: 0; }
  .btn-abrir-ficha { width: 100%; }
}

.btn-dm-acceso { background: rgba(168, 85, 247, 0.2); color: #c084fc; border: 1px solid #a855f7; padding: 0.4rem 0.8rem; border-radius: 6px; font-weight: bold; font-family: 'Cinzel', serif; cursor: pointer; transition: 0.2s; }
.btn-dm-acceso:hover { background: #a855f7; color: white; box-shadow: 0 0 15px rgba(168,85,247,0.4); }
</style>