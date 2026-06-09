<script setup>
const supabase = useSupabaseClient()
const user = useSupabaseUser()

// ¡ACÁ CONTROLAS LA CANTIDAD DE LUCES!
const cantidadLuces = 25 
const luces = ref([])

watchEffect(() => {
  if (user.value) {
    navigateTo('/dashboard')
  }
})

// Generamos las luces con posiciones y movimientos aleatorios (Magia de Caos)
onMounted(() => {
  for (let i = 0; i < cantidadLuces; i++) {
    luces.value.push({
      id: i,
      size: Math.random() * 6 + 3, // Tamaño entre 3px y 9px
      startX: Math.random() * 100, // Posición inicial X (0% a 100%)
      startY: Math.random() * 100, // Posición inicial Y (0% a 100%)
      moveX: (Math.random() - 0.5) * 600, // Movimiento errático X (hacia los lados)
      moveY: (Math.random() - 0.5) * 600, // Movimiento errático Y (hacia arriba/abajo)
      duracion: Math.random() * 10 + 8, // Entre 8 y 18 segundos
      delay: Math.random() * -20 // Delay negativo para que ya estén en movimiento
    })
  }
})

const loginConGoogle = async () => {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: window.location.origin + '/dashboard' 
    }
  })

  if (error) {
    console.error('Pifia crítica en el login:', error.message)
  }
}
</script>

<template>
  <div class="pantalla-magica">
    <div class="niebla"></div>
    
    <div class="lucecitas">
      <div 
        v-for="luz in luces" 
        :key="luz.id" 
        class="luz"
        :style="{
          width: `${luz.size}px`,
          height: `${luz.size}px`,
          left: `${luz.startX}%`,
          top: `${luz.startY}%`,
          animationDuration: `${luz.duracion}s`,
          animationDelay: `${luz.delay}s`,
          '--moveX': `${luz.moveX}px`,
          '--moveY': `${luz.moveY}px`
        }"
      ></div>
    </div>
    
    <div class="tarjeta-grimorio">
      <div class="brillo-superior"></div>
      <h1 class="titulo-epico">La Taberna<br>del DM</h1>
      <p class="subtitulo">Abre el portal con tu verdadera identidad</p>
      
      <button @click="loginConGoogle" class="btn-portal">
        <svg class="icono" viewBox="0 0 24 24">
          <path fill="currentColor" d="M12.545,10.239v3.821h5.445c-0.712,2.315-2.647,3.972-5.445,3.972c-3.332,0-6.033-2.701-6.033-6.032s2.701-6.032,6.033-6.032c1.498,0,2.866,0.549,3.921,1.453l2.814-2.814C17.503,2.988,15.139,2,12.545,2C7.021,2,2.543,6.477,2.543,12s4.478,10,10.002,10c8.396,0,10.249-7.85,9.426-11.748L12.545,10.239z"/>
        </svg>
        Cruzar el Umbral con Google
      </button>
    </div>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@700&display=swap');

.pantalla-magica { min-height: 100vh; display: flex; align-items: center; justify-content: center; background: radial-gradient(circle at center, #0f0318 0%, #010003 100%); position: relative; overflow: hidden; }
.niebla { position: absolute; top: -50%; left: -50%; width: 200%; height: 200%; background: radial-gradient(circle, rgba(58, 16, 92, 0.06) 10%, transparent 65%); animation: rotarMagia 35s linear infinite; pointer-events: none; }

/* --- LUCES ALEATORIAS (CSS Variables) --- */
.lucecitas { position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none; }
.luz { 
  position: absolute; 
  background: #d8b4fe; 
  border-radius: 50%; 
  box-shadow: 0 0 10px 2px #9333ea, 0 0 20px 4px rgba(168, 85, 247, 0.4);
  opacity: 0; 
  /* Usamos alternate para que vayan y vengan suavemente */
  animation: derivaCaotica linear infinite alternate; 
}

@keyframes derivaCaotica {
  0% { transform: translate(0, 0) scale(0.5); opacity: 0; }
  25% { opacity: 0.8; }
  75% { opacity: 0.8; }
  100% { transform: translate(var(--moveX), var(--moveY)) scale(1.2); opacity: 0; }
}
@keyframes rotarMagia { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }

/* --- TARJETA Y BOTON --- */
.tarjeta-grimorio { position: relative; background: rgba(8, 2, 14, 0.7); backdrop-filter: blur(14px); padding: 3rem 2.5rem; border-radius: 16px; border: 1px solid rgba(88, 28, 135, 0.4); box-shadow: 0 0 50px rgba(46, 16, 101, 0.6), inset 0 0 20px rgba(88, 28, 135, 0.2); max-width: 420px; width: 90%; text-align: center; z-index: 10; }
.brillo-superior { position: absolute; top: -1px; left: 50%; transform: translateX(-50%); width: 60%; height: 2px; background: linear-gradient(90deg, transparent, #7e22ce, transparent); box-shadow: 0 0 15px #9333ea; }
.titulo-epico { font-family: 'Cinzel', serif; font-size: 2.8rem; margin-top: 0; margin-bottom: 0.5rem; background: linear-gradient(180deg, #fde047 0%, #b45309 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; filter: drop-shadow(0 4px 6px rgba(0,0,0,0.8)); line-height: 1.1; }
.subtitulo { color: #576579; font-size: 1.1rem; margin-bottom: 2.5rem; font-style: italic; letter-spacing: 0.5px; }
.btn-portal { width: 100%; display: flex; align-items: center; justify-content: center; gap: 0.75rem; background: linear-gradient(135deg, #2e1065, #170530); color: #d8b4fe; font-weight: bold; padding: 1rem; border: 1px solid #581c87; border-radius: 8px; cursor: pointer; font-size: 1.1rem; transition: all 0.3s ease; box-shadow: 0 4px 15px rgba(46, 16, 101, 0.8); letter-spacing: 0.5px; }
.btn-portal:hover { background: linear-gradient(135deg, #3b0764, #2e1065); border-color: #7e22ce; color: #ffffff; transform: translateY(-2px); box-shadow: 0 6px 20px rgba(88, 28, 135, 0.9); }
.btn-portal:active { transform: translateY(1px); }
.icono { width: 1.5rem; height: 1.5rem; }
</style>