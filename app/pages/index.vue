<script setup>
const supabase = useSupabaseClient()
const user = useSupabaseUser()

watchEffect(() => {
  if (user.value) {
    navigateTo('/dashboard')
  }
})

const ingresando = ref(false)
const errorLogin = ref('')
const loginConGoogle = async () => {
  if (ingresando.value) return
  ingresando.value = true
  errorLogin.value = ''
  try {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: window.location.origin + '/dashboard' }
    })
    if (error) throw error
  } catch {
    errorLogin.value = 'No se pudo iniciar sesión con Google. Volvé a intentarlo.'
    ingresando.value = false
  }
}
</script>

<template>
  <main class="entrada">
    <section class="umbral" aria-labelledby="nombre-taberna">
      <h1 id="nombre-taberna">La Taberna<br><span>del DM</span></h1>
      <p>Tus campañas, personajes y mesas de juego.</p>
      <p v-if="errorLogin" role="alert">{{ errorLogin }}</p>
      <button :disabled="ingresando" @click="loginConGoogle">
        <svg class="icono" aria-hidden="true" viewBox="0 0 24 24">
          <path fill="currentColor" d="M12.545,10.239v3.821h5.445c-0.712,2.315-2.647,3.972-5.445,3.972c-3.332,0-6.033-2.701-6.033-6.032s2.701-6.032,6.033-6.032c1.498,0,2.866,0.549,3.921,1.453l2.814-2.814C17.503,2.988,15.139,2,12.545,2C7.021,2,2.543,6.477,2.543,12s4.478,10,10.002,10c8.396,0,10.249-7.85,9.426-11.748L12.545,10.239z"/>
        </svg>
        {{ ingresando ? 'Abriendo Google…' : 'Entrar con Google' }}
      </button>
      <NuxtLink to="/versiones">Historial de versiones</NuxtLink>
    </section>
  </main>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&display=swap');
.entrada {
  min-height: 100svh;
  display: grid;
  align-items: center;
  padding: clamp(1.5rem, 8vw, 9rem);
  background: linear-gradient(90deg, #080707f5 0%, #100d0be8 32%, #100e0b45 78%), url('/fondo-taberna.webp') center / cover;
}
.umbral { max-width: 33rem; padding-block: 2rem; color: #f1e7d8; }
h1 { font: 600 clamp(3.1rem, 7vw, 6.7rem)/1.04 Cinzel, Georgia, serif; letter-spacing: -.045em; margin: 0; }
h1 span { color: #edc77d; }
p { color: #e1d6c5; font-size: 1.1rem; margin: 1.2rem 0 2rem; }
button { display: inline-flex; gap: .8rem; align-items: center; padding: .85rem 1.25rem; border: 1px solid #f1cd82; border-radius: .45rem; background: #e9bb67; color: #24190b; font-weight: 700; cursor: pointer; }
button:hover { background: #f8d89c; }
.icono { width: 1.2rem; height: 1.2rem; }
a { display: flex; width: fit-content; align-items: center; min-height: 44px; color: #dbc9af; text-decoration: underline; text-underline-offset: .25em; margin-top: .6rem; }
@media (max-width: 600px) {
  .entrada { align-items: end; background: linear-gradient(0deg, #090807 6%, #100d0be8 41%, #100d0b28 92%), url('/fondo-taberna.webp') 64% center / cover; }
}
</style>
