  <script setup>
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()
  const perfil = ref(null)
  const cargando = ref(true)
  
  // Función para buscar el perfil en la base de datos y saber si es DM
  const cargarPerfil = async () => {
    if (!user.value) return
    
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.value.id)
      .single()
  
    if (data) {
      perfil.value = data
    } else if (error) {
      console.error('Error al leer las runas (perfil):', error)
    }
    
    cargando.value = false
  }
  
  // Función para salir
  const cerrarSesion = async () => {
    await supabase.auth.signOut()
    navigateTo('/')
  }
  
  // Cuando la página se arma, ejecutamos la búsqueda del perfil
  onMounted(() => {
    cargarPerfil()
  })

  const creandoCampaña = ref(false)
const nombreNuevaCampaña = ref('')

const crearCampaña = async () => {
  if (!nombreNuevaCampaña.value) return

  const { error } = await supabase
    .from('campaigns')
    .insert([{ 
      nombre_campanya: nombreNuevaCampaña.value, 
      dm_id: user.value.id 
    }])

  if (!error) {
    creandoCampaña.value = false
    nombreNuevaCampaña.value = ''
    alert('¡Campaña creada con éxito!')
    // Acá recargaríamos la lista de campañas luego
  }
}
  </script>

<template>
    <div class="contenedor-principal">
      <nav class="navbar">
        <h1>D&D Manager</h1>
        <div>
          <span v-if="perfil">Hola, {{ perfil.nombre }}</span>
          <button @click="cerrarSesion">Abandonar Taberna</button>
        </div>
      </nav>
  
      <div v-if="cargando">Consultando pergaminos...</div>
  
      <div v-else-if="perfil?.is_dm" class="panel-dm">
        <div class="header-panel">
          <h2>Panel de Dungeon Master</h2>
          <button @click="creandoCampaña = true">+ Nueva Campaña</button>
        </div>
  
        <div v-if="creandoCampaña" class="modal-overlay">
          <div class="modal-card">
            <h3>Nueva Campaña</h3>
            <input v-model="nombreNuevaCampaña" placeholder="Nombre del mundo..." />
            <div class="acciones">
              <button @click="creandoCampaña = false">Cancelar</button>
              <button @click="crearCampaña">Crear</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </template>
  
  <style scoped>
  .contenedor-principal {
    min-height: 100vh;
    background-color: #111827;
    color: white;
    padding: 2rem;
  }
  
  .navbar {
    display: flex;
    justify-content: space-between;
    border-bottom: 1px solid #374151;
    padding-bottom: 1rem;
  }
  
  .panel-dm {
    background-color: #1f2937;
    padding: 1.5rem;
    border-radius: 8px;
    border: 1px solid #9333ea; /* Color púrpura */
  }
  
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.7);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .modal-card {
    background: #1f2937;
    padding: 2rem;
    border-radius: 8px;
    border: 1px solid #9333ea;
  }
  
  /* Acá podés seguir agregando tus estilos tranqui sin ensuciar el HTML */
  input {
    width: 100%;
    background: #000;
    border: 1px solid #4b5563;
    padding: 10px;
    margin: 10px 0;
    color: white;
  }
  </style>