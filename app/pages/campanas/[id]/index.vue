<script setup>
import { ref, onMounted } from 'vue'

const route = useRoute()
const router = useRouter()
const supabase = useSupabaseClient()

const cargando = ref(true)
const campana = ref({ nombre: 'Cargando campaña...' })

// Listas separadas
const listaPersonajes = ref([])
const listaNpcs = ref([])
const listaEnemigos = ref([])

const editandoImagen = ref(false)
const nuevaUrlImagen = ref('')

const guardarImagenCampana = async () => {
  await supabase.from('campaigns').update({ imagen_url: nuevaUrlImagen.value }).eq('id', route.params.id)
  campana.value.imagen_url = nuevaUrlImagen.value
  editandoImagen.value = false
}

const cargarDatosCampana = async () => {
  cargando.value = true
  try {
    const { data: campanaData } = await supabase.from('campaigns').select('*').eq('id', route.params.id).single()
    if (campanaData) campana.value = campanaData

    // Traemos a TODOS (PJs, NPCs y Enemigos) de una sola vez
    const { data: personajesData } = await supabase
      .from('characters')
      .select('id, nombre_pj, raza, clase, nivel, player_email, imagen_url, tipo, dificultad')
      .eq('campaign_id', route.params.id)
    
    if (personajesData) {
      // Filtramos en memoria
      listaPersonajes.value = personajesData.filter(p => p.tipo === 'pj' || !p.tipo)
      listaNpcs.value = personajesData.filter(p => p.tipo === 'npc')
      listaEnemigos.value = personajesData.filter(p => p.tipo === 'enemigo')
    }
  } catch (err) {
    console.error("Error al forjar los datos:", err)
  } finally {
    cargando.value = false
  }
}

const borrarCampana = async () => {
  const confirmacion = confirm("⚠️ ATENCIÓN: ¿Estás seguro de que deseas destruir esta campaña para siempre?\n\nEsto eliminará absolutamente todo: personajes, NPCs, enemigos, el historial de dados y el estado de la mesa. No hay vuelta atrás.")
  if (confirmacion) {
    await supabase.from('campaigns').delete().eq('id', route.params.id)
    router.push('/campanas')
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
          <button @click="router.push('../dashboard')" class="btn-regresar" title="Volver al Dashboard">←</button>
          <h1 class="titulo-campana">{{ campana.nombre }}</h1>
        </div>
        
        <div class="header-centro">
          <button @click="router.push(`/campanas/${route.params.id}/dm`)" class="btn-dm-acceso">
            👁️ Entrar a la Mesa (DM)
          </button>
          <button @click="router.push(`/campanas/${route.params.id}/lugares`)" class="btn-herramienta">
            🏪 Tiendas y Lugares
          </button>
        </div>

        <div class="header-der">
          <div class="dropdown-creacion">
            <button class="btn-nuevo">+ Crear Entidad ▼</button>
            <div class="dropdown-menu">
              <button @click="router.push(`/personajes/nuevo?campana=${route.params.id}&tipo=pj`)">Jugador</button>
              <button @click="router.push(`/personajes/nuevo?campana=${route.params.id}&tipo=npc`)">NPC / Aliado</button>
              <button @click="router.push(`/personajes/nuevo?campana=${route.params.id}&tipo=enemigo`)">Monstruo / Enemigo</button>
            </div>
          </div>
          <button @click="editandoImagen = true" class="btn-herramienta" title="Cambiar Portada">🖼️</button>
          <button @click="borrarCampana" class="btn-borrar-campana" title="Destruir Campaña">Eliminar Campaña</button>
        </div>
      </div>

      <h2 class="subtitulo-seccion">Héroes de la Sesión</h2>
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
        <p class="texto-vacio">No hay héroes asignados a esta campaña todavía.</p>
      </div>

      <div class="divisor-campana"></div>

      <div class="grilla-entidades-bajas">
        
        <div class="bloque-entidades">
          <h2 class="subtitulo-seccion texto-verde">NPCs de la Campaña</h2>
          <div class="lista-mini">
            <div v-for="npc in listaNpcs" :key="npc.id" class="tarjeta-mini-entidad borde-verde" @click="router.push(`/personajes/${npc.id}`)">
              <div class="mini-avatar npc-bg"><span v-if="!npc.imagen_url">👤</span><img v-else :src="npc.imagen_url" /></div>
              <div class="mini-info">
                <h4>{{ npc.nombre_pj || 'NPC Desconocido' }}</h4>
                <span>Abrir Ficha</span>
              </div>
            </div>
            <p v-if="listaNpcs.length === 0" class="texto-vacio-mini">Sin NPCs forjados.</p>
          </div>
        </div>

        <div class="bloque-entidades">
          <h2 class="subtitulo-seccion texto-rojo">Enemigos / Monstruos</h2>
          <div class="lista-mini">
            <div v-for="en in listaEnemigos" :key="en.id" class="tarjeta-mini-entidad borde-rojo" @click="router.push(`/personajes/${en.id}`)">
              <div class="mini-avatar en-bg"><span v-if="!en.imagen_url">💀</span><img v-else :src="en.imagen_url" /></div>
              <div class="mini-info">
                <h4>{{ en.nombre_pj || 'Monstruo Desconocido' }}</h4>
                <span>CR: {{ en.dificultad || '-' }}</span>
              </div>
            </div>
            <p v-if="listaEnemigos.length === 0" class="texto-vacio-mini">Sin amenazas forjadas.</p>
          </div>
        </div>

      </div>

    </div>
  </div>

  <div v-if="editandoImagen" class="modal-dm-overlay" @click.self="editandoImagen = false">
      <div class="modal-dm-sheet form-medium">
        <h3>🖼️ Cambiar Portada de la Campaña</h3>
        
        <input type="text" v-model="nuevaUrlImagen" placeholder="URL de la imagen (ej: https://...)" class="input-search-modal mb-corto" />
        
        <div v-if="nuevaUrlImagen" class="preview-imagen">
          <img :src="nuevaUrlImagen" alt="Preview" />
        </div>

        <div class="acciones-modal">
          <button class="btn-cancelar" @click="editandoImagen = false">Cancelar</button>
          <button class="btn-accion-dm dorado" @click="guardarImagenCampana">Guardar Portada</button>
        </div>
      </div>
    </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Inter:wght@400;600;700&display=swap');

.pantalla-campana { min-height: 100vh; background-color: #050505; color: #cbd5e1; font-family: 'Inter', sans-serif; position: relative; padding: 2rem 1rem; overflow-x: hidden; }
.filtro-oscuro { position: absolute; inset: 0; background: radial-gradient(circle at top, #111 0%, #000 100%); z-index: 0; }
.contenedor-principal { position: relative; z-index: 10; max-width: 1200px; margin: 0 auto; width: 100%; }

.cargando-box { min-height: 60vh; display: flex; align-items: center; justify-content: center; position: relative; z-index: 10; }
.texto-cargando { font-family: 'Cinzel', serif; font-size: 1.5rem; color: #64748b; text-align: center; }

/* REDISEÑO HEADER CAMPAÑA */
.header-campana { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #1e293b; padding-bottom: 1.2rem; margin-bottom: 2rem; gap: 1rem; flex-wrap: wrap; background: rgba(10,10,12,0.8); padding: 1rem; border-radius: 12px; }
.header-izq { display: flex; align-items: center; gap: 1rem; }
.header-centro { display: flex; align-items: center; gap: 1rem; padding: 0.4rem; border-radius: 8px }
.header-der { display: flex; align-items: center; gap: 0.8rem; }
.btn-herramienta { background: transparent; border: 1px solid #475569; color: #cbd5e1; padding: 0.6rem 1rem; border-radius: 6px; cursor: pointer; font-weight: bold; transition: 0.2s; }
.btn-herramienta:hover { background: #1e293b; border-color: #94a3b8; }

/* DROPDOWN CREACIÓN */
.dropdown-creacion { position: relative; display: inline-block; }
.dropdown-creacion:hover .dropdown-menu { display: flex; }
.dropdown-menu { display: none; position: absolute; right: 0; top: 100%; background: #0a0a0c; border: 1px solid #3b82f6; border-radius: 8px; flex-direction: column; min-width: 180px; z-index: 50; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.8); }
.dropdown-menu button { background: transparent; border: none; border-bottom: 1px solid #1e293b; color: white; padding: 0.8rem 1rem; text-align: left; cursor: pointer; transition: 0.2s; }
.dropdown-menu button:hover { background: #1e3a8a; }
.dropdown-menu button:last-child { border-bottom: none; }

.btn-regresar { background: transparent; border: 1px solid #334155; color: #94a3b8; padding: 0.4rem 0.8rem; border-radius: 6px; cursor: pointer; font-weight: 600; font-size: 0.85rem; transition: 0.2s; }
.btn-regresar:hover { background: #1e293b; color: white; }
.titulo-campana { font-family: 'Cinzel', serif; font-size: 2.2rem; color: #facc15; margin: 0 1rem; line-height: 1.1; }

.btn-dm-acceso { background: rgba(168, 85, 247, 0.15); color: #c084fc; border: 1px solid #a855f7; padding: 0.5rem 1rem; border-radius: 6px; font-weight: bold; font-family: 'Cinzel', serif; cursor: pointer; transition: 0.2s; }
.btn-dm-acceso:hover { background: #a855f7; color: white; box-shadow: 0 0 15px rgba(168,85,247,0.4); transform: scale(1.05); }

/* BOTONES EXTRA HEADER */
.btn-ghost { background: transparent; border: 1px solid #475569; color: #cbd5e1; padding: 0.5rem 1rem; border-radius: 6px; cursor: pointer; font-weight: bold; transition: 0.2s; }
.btn-ghost:hover { background: #1e293b; border-color: #94a3b8; }
.btn-borrar-campana { background: rgba(239, 68, 68, 0.1); border: 1px solid #ef4444; color: #fca5a5; padding: 0.5rem 1rem; border-radius: 6px; cursor: pointer; font-weight: bold; transition: 0.2s; }
.btn-borrar-campana:hover { background: #ef4444; color: white; }

.btn-nuevo { background: transparent; border: 1px dashed #3b82f6; color: #3b82f6; padding: 0.6rem 1.2rem; border-radius: 6px; cursor: pointer; font-weight: bold; transition: 0.2s; font-size: 0.9rem; }
.btn-nuevo:hover { background: #3b82f6; color: white; box-shadow: 0 0 15px rgba(59, 130, 246, 0.4); }
.btn-nuevo.rojo { border-color: #ef4444; color: #fca5a5; }
.btn-nuevo.rojo:hover { background: #ef4444; color: white; box-shadow: 0 0 15px rgba(239, 68, 68, 0.4); }

.subtitulo-seccion { font-family: 'Cinzel', serif; font-size: 1.4rem; color: white; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; margin-bottom: 1.5rem; }

/* GRILLA JUGADORES */
.grilla-personajes { display: grid; grid-template-columns: repeat(auto-fill, minmax(500px, 1fr)); gap: 1.5rem; margin-bottom: 2rem; }
@media (max-width: 550px) { .grilla-personajes { grid-template-columns: 1fr; } }
.tarjeta-pj { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 12px; display: flex; align-items: center; padding: 1.2rem; transition: transform 0.2s, border-color 0.2s, box-shadow 0.2s; box-shadow: 0 5px 15px rgba(0,0,0,0.5); }
.tarjeta-pj:hover { transform: translateY(-3px); border-color: #3b82f6; box-shadow: 0 10px 25px rgba(0,0,0,0.85); }
.avatar-zona { flex-shrink: 0; width: 85px; height: 85px; margin-right: 1.5rem; }
.img-avatar { width: 100%; height: 100%; object-fit: cover; border-radius: 8px; border: 1px solid #27272a; }
.img-fallback { width: 100%; height: 100%; background: #111; border: 1px dashed #334155; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: 2.2rem; }
.info-zona { flex-grow: 1; display: flex; flex-direction: column; justify-content: center; gap: 0.5rem; min-width: 0; }
.pj-nombre { font-family: 'Cinzel', serif; font-size: 1.5rem; color: white; margin: 0; line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.pj-stats { display: flex; gap: 0.5rem; flex-wrap: wrap; }
.badge-stat { background: #141416; color: #94a3b8; font-size: 0.75rem; font-weight: 700; padding: 0.2rem 0.6rem; border-radius: 4px; border: 1px solid #1e293b; text-transform: uppercase; }
.badge-stat.highlight { color: #facc15; border-color: #b45309; background: rgba(250, 204, 21, 0.03); }
.font-mono { font-family: monospace; }
.pj-mail { font-size: 0.8rem; color: #475569; margin-top: 0.1rem; }
.accion-zona { flex-shrink: 0; padding-left: 1.2rem; border-left: 1px dashed #1e293b; display: flex; align-items: center; height: 70px; margin-left: 1rem; }
.btn-abrir-ficha { background: #1e3a8a; border: 1px solid #3b82f6; color: #bfdbfe; font-family: 'Cinzel', serif; font-weight: bold; font-size: 0.85rem; padding: 0.6rem 1rem; border-radius: 6px; cursor: pointer; transition: all 0.2s; white-space: nowrap; }
.btn-abrir-ficha:hover { background: #2563eb; color: white; transform: scale(1.03); }

.caja-vacia { background: #0a0a0c; border: 1px dashed #1e293b; border-radius: 12px; padding: 3rem; text-align: center; margin-bottom: 2rem; }
.texto-vacio { font-style: italic; color: #475569; font-size: 1rem; margin: 0; }

/* SEPARADOR Y ZONAS BAJAS */
.divisor-campana { height: 1px; background: dashed #1e293b; margin: 3rem 0 2rem 0; }
.grilla-entidades-bajas { display: grid; grid-template-columns: 1fr 1fr; gap: 2rem; }
.bloque-entidades { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 12px; padding: 1.5rem; }
.texto-verde { color: #10b981; border-color: #064e3b; }
.texto-rojo { color: #ef4444; border-color: #7f1d1d; }
.lista-mini { display: flex; flex-direction: column; gap: 0.8rem; }
.texto-vacio-mini { font-style: italic; color: #475569; font-size: 0.85rem; margin: 0; }

.tarjeta-mini-entidad { display: flex; align-items: center; background: #111; border: 1px solid #334155; border-radius: 8px; padding: 0.8rem; cursor: pointer; transition: 0.2s; }
.tarjeta-mini-entidad:hover { transform: translateX(5px); background: #1a1a1f; }
.borde-verde:hover { border-color: #10b981; }
.borde-rojo:hover { border-color: #ef4444; }

.mini-avatar { width: 45px; height: 45px; border-radius: 6px; display: flex; align-items: center; justify-content: center; font-size: 1.2rem; margin-right: 1rem; overflow: hidden; }
.mini-avatar img { width: 100%; height: 100%; object-fit: cover; }
.npc-bg { background: rgba(16, 185, 129, 0.1); border: 1px solid #10b981; }
.en-bg { background: rgba(239, 68, 68, 0.1); border: 1px solid #ef4444; }

.mini-info h4 { margin: 0 0 0.2rem 0; font-size: 1rem; color: white; }
.mini-info span { font-size: 0.75rem; color: #94a3b8; font-family: monospace; }

@media (max-width: 768px) {
  .grilla-entidades-bajas { grid-template-columns: 1fr; }
}

/* MODAL CAMBIAR PORTADA */
.modal-dm-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.85); backdrop-filter: blur(5px); z-index: 99999; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.modal-dm-sheet { background: #0a0a0c; border: 2px solid #334155; border-radius: 12px; padding: 2rem; width: 100%; max-width: 500px; box-shadow: 0 0 30px rgba(0, 0, 0, 0.8); }
.modal-dm-sheet h3 { font-family: 'Cinzel', serif; color: #facc15; margin: 0 0 1.5rem 0; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; }
.input-search-modal { width: 100%; background: #111; border: 1px solid #475569; color: white; padding: 0.8rem; border-radius: 6px; font-size: 1rem; outline: none; }
.input-search-modal:focus { border-color: #3b82f6; }
.mb-corto { margin-bottom: 1.5rem; }
.preview-imagen { width: 100%; height: 200px; border-radius: 8px; border: 1px dashed #b45309; overflow: hidden; margin-bottom: 1.5rem; display: flex; justify-content: center; align-items: center; background: rgba(0,0,0,0.5); }
.preview-imagen img { width: 100%; height: 100%; object-fit: cover; }

.acciones-modal { display: flex; justify-content: flex-end; gap: 1rem; }
.btn-cancelar { background: transparent; border: 1px solid #64748b; color: #94a3b8; padding: 0.6rem 1.2rem; border-radius: 6px; cursor: pointer; font-weight: bold; transition: 0.2s; }
.btn-cancelar:hover { background: #1e293b; color: white; }
.btn-accion-dm.dorado { background: #b45309; border: 1px solid #d97706; color: white; padding: 0.6rem 1.2rem; border-radius: 6px; cursor: pointer; font-weight: bold; font-family: 'Cinzel', serif; box-shadow: 0 0 10px rgba(245, 158, 11, 0.2); transition: 0.2s; }
.btn-accion-dm.dorado:hover { background: #d97706; transform: scale(1.02); }
</style>