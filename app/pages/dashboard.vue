<script setup>
const supabase = useSupabaseClient()
// Mantenemos esta variable por si Nuxt la necesita internamente, pero no confiaremos en ella
const user = useSupabaseUser() 

const perfil = ref(null)
const cargando = ref(true)

// Variables DM
const creandoCampaña = ref(false)
const nombreNuevaCampaña = ref('')
const imagenNuevaCampaña = ref('') // NUEVO: URL de la imagen
const misCampañas = ref([])

// Variables Jugador
const misPersonajes = ref([])

// Control de YouTube
const musicaSonando = ref(false)
let player = null

const toggleMusica = () => {
  if (!player) return
  
  if (musicaSonando.value) {
    player.mute()
    musicaSonando.value = false
  } else {
    player.unMute()
    player.playVideo()
    musicaSonando.value = true
  }
}

// Pasamos el ID directamente como parámetro para no depender de user.value
const cargarCampañasDM = async (dmId) => {
  const { data } = await supabase.from('campaigns').select('*').eq('dm_id', dmId).order('created_at', { ascending: false })
  if (data) misCampañas.value = data
}

const cargarPersonajesJugador = async (email) => {
  const { data } = await supabase.from('characters').select('*, campaigns(nombre_campanya)').eq('player_email', email)
  if (data) misPersonajes.value = data
}

const crearCampaña = async () => {
  if (!nombreNuevaCampaña.value || !perfil.value) return
  const { error } = await supabase.from('campaigns').insert([{ 
    nombre_campanya: nombreNuevaCampaña.value, 
    imagen_url: imagenNuevaCampaña.value, // NUEVO: Guardar imagen
    dm_id: perfil.value.id 
  }])
  
  if (!error) {
    creandoCampaña.value = false
    nombreNuevaCampaña.value = ''
    imagenNuevaCampaña.value = '' // NUEVO: Limpiar input
    await cargarCampañasDM(perfil.value.id)
  }
}

// 🛡️ MÉTODO A PRUEBA DE BALAS PARA OBTENER LA SESIÓN
const cargarPerfilFuerte = async () => {
  try {
    // 1. Buscamos la sesión del navegador
    const { data: authData } = await supabase.auth.getSession()
    if (!authData?.session?.user) {
      console.warn("Sin sesión. Cerrando puerta.")
      cargando.value = false
      return
    }

    const userEmail = authData.session.user.email

    // 2. Buscamos TU fila exacta por email y la pedimos como objeto único (.single())
    const { data, error } = await supabase.from('profiles')
      .select('*')
      .eq('email', userEmail)
      .single() 
    
    if (error) {
      console.error("Error al buscar el perfil:", error.message)
    }

    // 3. Asignamos y comprobamos
    if (data) {
      perfil.value = data // Ahora sí es un objeto con propiedades
      
      if (data.is_dm === true || data.is_dm === 'true') {
        console.log("¡Bienvenido, Dungeon Master!")
        await cargarCampañasDM(data.id)
      } else {
        console.log("Bienvenido, Jugador.")
        await cargarPersonajesJugador(userEmail)
      }
    }
  } catch (error) {
    console.error("Error crítico:", error)
  } finally {
    cargando.value = false
  }
}

const cerrarSesion = async () => {
  await supabase.auth.signOut()
  navigateTo('/')
}

onMounted(() => {
  // Disparamos la carga fuerte apenas el componente se monta en el navegador
  cargarPerfilFuerte()

  // Inyectamos YouTube
  const tag = document.createElement('script')
  tag.src = "https://www.youtube.com/iframe_api"
  const firstScriptTag = document.getElementsByTagName('script')[0]
  firstScriptTag.parentNode.insertBefore(tag, firstScriptTag)

  window.onYouTubeIframeAPIReady = () => {
    player = new window.YT.Player('yt-player', {
      height: '0', width: '0', videoId: 'vyg5jJrZ42s',
      playerVars: { 
        autoplay: 1, 
        loop: 1, 
        playlist: 'vyg5jJrZ42s', 
        controls: 0, 
        origin: window.location.origin,
        mute: 1
      },
      events: { 
        onReady: (event) => {
          event.target.setVolume(20)
          event.target.unMute()
          event.target.playVideo()
        } 
      } 
    })
  }

  document.addEventListener('click', () => {
    if (player && !musicaSonando.value) {
      player.unMute()
      player.playVideo()
      musicaSonando.value = true
    }
  }, { once: true }) // Solo funciona la primera vez que tocan algo
})
</script>

<template>
  <div class="pantalla-taberna">
    <div class="filtro-oscuro"></div>

    <div id="yt-player" style="position: absolute; top: -9999px;"></div>

    <div class="contenedor-principal">
      <nav class="navbar panel-glass">
        <h1 class="titulo-epico">D&D Manager</h1>
        <div class="usuario-menu">
          <button @click="toggleMusica" class="btn-musica" :title="musicaSonando ? 'Silenciar Taberna' : 'Escuchar Taberna'">
            {{ musicaSonando ? '🔊' : '🔇' }}
          </button>
          
          <span v-if="perfil" class="saludo">Saludos, <strong class="texto-dorado">{{ perfil.nombre }}</strong></span>
          <button @click="cerrarSesion" class="btn-salir">Abandonar Taberna</button>
        </div>
      </nav>

      <ClientOnly fallback-tag="div" fallback="Invocando la taberna...">
        
        <div v-if="cargando" class="cargando">Consultando los pergaminos de la creación...</div>

        <div v-else-if="perfil?.is_dm" class="panel-principal panel-glass dm-borde">
          <div class="header-panel">
            <h2 class="subtitulo-seccion dm-color">Mis Campañas (Dungeon Master)</h2>
            <button @click="creandoCampaña = true" class="btn-accion-dm">+ Forjar Nueva Campaña</button>
          </div>

          <div v-if="misCampañas.length > 0" class="grilla">
            <div v-for="campana in misCampañas" :key="campana.id" class="tarjeta-campana">
              
              <div v-if="campana.imagen_url" class="imagen-portada-campana">
                <img :src="campana.imagen_url" :alt="campana.nombre_campanya" />
              </div>
              <div v-else class="icono-campana">🗺️</div>
              
              <div class="info-campana">
                <h3 class="texto-dm">{{ campana.nombre_campanya }}</h3>
                <p class="detalle-campana">Mundo Activo</p>
                <NuxtLink :to="`/campanas/${campana.id}`" class="btn-link-dm">Entrar al Mundo</NuxtLink>
              </div>
            </div>
          </div>
          <div v-else class="vacio">No has forjado ningún mundo todavía. Crea tu primera campaña.</div>

          <div v-if="creandoCampaña" class="modal-overlay">
            <div class="modal-card panel-glass">
              <h3 class="texto-dm">Nueva Campaña</h3>
              
              <input v-model="nombreNuevaCampaña" placeholder="Nombre de tu mundo..." class="input-magico mb-corto" />
              <input v-model="imagenNuevaCampaña" placeholder="URL de la imagen (Opcional)..." class="input-magico" />
              
              <div v-if="imagenNuevaCampaña" class="preview-imagen">
                <img :src="imagenNuevaCampaña" alt="Preview" />
              </div>

              <div class="acciones">
                <button @click="creandoCampaña = false" class="btn-cancelar">Cancelar</button>
                <button @click="crearCampaña" class="btn-accion-dm">Crear Mundo</button>
              </div>
            </div>
          </div>
        </div>

        <div v-else class="panel-principal panel-glass jugador-borde">
          <h2 class="subtitulo-seccion jugador-color">Mis Héroes</h2>
          
          <div v-if="misPersonajes.length > 0" class="grilla">
            <div v-for="pj in misPersonajes" :key="pj.id" class="tarjeta-pj flex-tarjeta">
              <div class="avatar-pj">
                <img v-if="pj.imagen_url" :src="pj.imagen_url" :alt="pj.nombre_pj" />
                <div v-else class="avatar-placeholder">🛡️</div>
              </div>
              
              <div class="info-pj">
                <h3 class="texto-jugador">{{ pj.nombre_pj }}</h3>
                <p class="detalle-pj">{{ pj.raza }} - {{ pj.clase }} (Nivel {{ pj.nivel }})</p>
                <p class="campana-pj">Campaña: {{ pj.campaigns?.nombre_campanya }}</p>
                <NuxtLink :to="`/personajes/${pj.id}`" class="btn-link-jugador">Abrir Ficha</NuxtLink>
              </div>
            </div>
          </div>
          <div v-else class="vacio">
            No tienes personajes. El DM debe asignarte uno usando tu correo: <span class="texto-dorado">{{ user?.email }}</span>
          </div>
        </div>
        
      </ClientOnly>
    </div>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@700&display=swap');

/* FONDO DE TABERNA REPARADO */
.pantalla-taberna { 
  min-height: 100vh; 
  /* Imagen de alta calidad de una taberna clásica de madera */
  background-image: url('fondoTaberna.png'); 
  background-size: cover; 
  background-position: center; 
  background-attachment: fixed;
  position: relative; 
  overflow-x: hidden; 
  color: #e2e8f0; 
}

.filtro-oscuro { position: absolute; top: 0; left: 0; width: 100%; height: 100%; background: rgba(9, 5, 14, 0.631); pointer-events: none; z-index: 0; }
.contenedor-principal { position: relative; z-index: 10; max-width: 1200px; margin: 0 auto; padding: 2rem; }
.panel-glass { background: rgba(15, 23, 42, 0.7); backdrop-filter: blur(16px); border: 1px solid rgba(255, 255, 255, 0.1); box-shadow: 0 20px 40px rgba(0,0,0,0.7); border-radius: 12px; }

/* NAVBAR Y BOTONES GLOBALES */
.navbar { display: flex; justify-content: space-between; align-items: center; padding: 1.5rem 2rem; margin-bottom: 2rem; }
.titulo-epico { font-family: 'Cinzel', serif; font-size: 2.2rem; margin: 0; background: linear-gradient(180deg, #fde047 0%, #b45309 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; filter: drop-shadow(0 2px 4px rgba(0,0,0,0.8)); }
.usuario-menu { display: flex; align-items: center; gap: 1.5rem; }
.saludo { color: #94a3b8; font-size: 1.1rem; }
.texto-dorado { color: #facc15; }
.btn-musica { background: rgba(30, 41, 59, 0.8); border: 1px solid #475569; border-radius: 50%; width: 40px; height: 40px; cursor: pointer; font-size: 1.2rem; transition: all 0.2s; display: flex; align-items: center; justify-content: center; }
.btn-musica:hover { background: #334155; transform: scale(1.1); }
.btn-salir { background: transparent; color: #94a3b8; border: 1px solid #475569; padding: 0.5rem 1rem; border-radius: 6px; cursor: pointer; transition: all 0.2s; font-weight: bold; }
.btn-salir:hover { background: #ef4444; color: white; border-color: #ef4444; }

/* PANELES GENERALES */
.panel-principal { padding: 2.5rem; }
.dm-borde { border-top: 4px solid #9333ea; }
.jugador-borde { border-top: 4px solid #3b82f6; }
.header-panel { display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem; border-bottom: 1px solid rgba(255, 255, 255, 0.1); padding-bottom: 1rem; }
.subtitulo-seccion { font-family: 'Cinzel', serif; font-size: 2rem; margin: 0; }
.dm-color { color: #c084fc; }
.jugador-color { color: #60a5fa; }
.texto-dm { color: #e9d5ff; font-family: 'Cinzel', serif; font-size: 1.5rem; margin-top: 0; margin-bottom: 0.5rem; }
.texto-jugador { color: #bfdbfe; font-family: 'Cinzel', serif; font-size: 1.5rem; margin-top: 0; margin-bottom: 0.5rem; }
.cargando { text-align: center; color: #a78bfa; font-style: italic; margin-top: 4rem; font-size: 1.2rem; }
.vacio { text-align: center; padding: 3rem; color: #94a3b8; border: 2px dashed #475569; border-radius: 8px; font-style: italic; font-size: 1.1rem; }

/* BOTONES ESPECÍFICOS */
.btn-accion-dm { background: linear-gradient(135deg, #7e22ce, #581c87); color: white; border: 1px solid #9333ea; padding: 0.8rem 1.5rem; border-radius: 6px; cursor: pointer; font-weight: bold; transition: all 0.2s; font-size: 1rem; }
.btn-accion-dm:hover { background: linear-gradient(135deg, #9333ea, #6b21a8); transform: translateY(-2px); box-shadow: 0 4px 15px rgba(147, 51, 234, 0.5); }

/* GRILLAS Y TARJETAS DE CAMPAÑA */
.grilla { display: grid; grid-template-columns: repeat(auto-fill, minmax(350px, 1fr)); gap: 2rem; }
.tarjeta-campana { background: rgba(30, 27, 75, 0.6); padding: 1.5rem; border-radius: 12px; border: 1px solid rgba(147, 51, 234, 0.3); transition: all 0.3s; display: flex; gap: 1.5rem; align-items: center; }
.tarjeta-campana:hover { transform: translateY(-5px); border-color: #c084fc; box-shadow: 0 10px 20px rgba(88, 28, 135, 0.4); }

.icono-campana { font-size: 3rem; background: rgba(15, 23, 42, 0.8); padding: 1rem; border-radius: 12px; border: 1px solid #7e22ce; flex-shrink: 0; }
/* ESTILO NUEVO PARA LA PORTADA DE CAMPAÑA */
.imagen-portada-campana { width: 80px; height: 80px; flex-shrink: 0; border-radius: 12px; overflow: hidden; border: 2px solid #7e22ce; background: #0f172a; box-shadow: 0 4px 10px rgba(0,0,0,0.5); }
.imagen-portada-campana img { width: 100%; height: 100%; object-fit: cover; }

.info-campana { flex-grow: 1; }
.detalle-campana { color: #a78bfa; font-size: 0.9rem; margin-bottom: 1rem; font-style: italic; }
.btn-link-dm { display: block; padding: 0.6rem 1rem; border-radius: 6px; text-decoration: none; text-align: center; font-weight: bold; background: #581c87; color: #e9d5ff; border: 1px solid #9333ea; transition: all 0.2s; }
.btn-link-dm:hover { background: #7e22ce; color: white; }

/* Tarjeta Jugador */
.tarjeta-pj { background: rgba(15, 30, 60, 0.6); padding: 1.5rem; border-radius: 12px; border: 1px solid rgba(59, 130, 246, 0.3); transition: all 0.3s; }
.tarjeta-pj:hover { transform: translateY(-5px); border-color: #60a5fa; box-shadow: 0 10px 20px rgba(30, 58, 138, 0.4); }
.flex-tarjeta { display: flex; gap: 1.5rem; align-items: center; }
.avatar-pj { flex-shrink: 0; width: 90px; height: 90px; border-radius: 12px; overflow: hidden; border: 2px solid #3b82f6; background: #0f172a; box-shadow: 0 4px 10px rgba(0,0,0,0.5); }
.avatar-pj img { width: 100%; height: 100%; object-fit: cover; }
.avatar-placeholder { width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; font-size: 2.5rem; color: #475569; }
.info-pj { flex-grow: 1; }
.detalle-pj { color: #94a3b8; margin: 0.3rem 0; font-size: 0.95rem; }
.campana-pj { color: #60a5fa; font-size: 0.85rem; font-style: italic; margin-bottom: 1rem; }
.btn-link-jugador { display: block; padding: 0.6rem 1rem; border-radius: 6px; text-decoration: none; text-align: center; font-weight: bold; background: #1e3a8a; color: #bfdbfe; border: 1px solid #2563eb; transition: all 0.2s; }
.btn-link-jugador:hover { background: #2563eb; color: white; }

/* MODALES Y PREVIEW */
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.85); display: flex; align-items: center; justify-content: center; z-index: 50; }
.modal-card { padding: 2.5rem; width: 100%; max-width: 450px; border: 1px solid #8b5cf6; }
.modal-card h3 { border-bottom: 1px solid rgba(139, 92, 246, 0.3); padding-bottom: 0.5rem; margin-bottom: 1.5rem; }

.input-magico { width: 100%; background: rgba(2, 0, 5, 0.8); border: 1px solid #64748b; padding: 1rem; color: white; margin-bottom: 1.5rem; border-radius: 6px; font-size: 1rem; }
.input-magico:focus { outline: none; border-color: #a855f7; box-shadow: 0 0 15px rgba(168, 85, 247, 0.4); }
.mb-corto { margin-bottom: 0.8rem; }

.preview-imagen { width: 100%; height: 140px; border-radius: 8px; border: 1px dashed #a855f7; overflow: hidden; margin-bottom: 1.5rem; display: flex; justify-content: center; align-items: center; background: rgba(0,0,0,0.5); }
.preview-imagen img { width: 100%; height: 100%; object-fit: cover; }

.acciones { display: flex; justify-content: flex-end; gap: 1rem; }
.btn-cancelar { background: transparent; color: #94a3b8; border: none; cursor: pointer; padding: 0.5rem 1rem; font-weight: bold; }
.btn-cancelar:hover { color: white; }
</style>