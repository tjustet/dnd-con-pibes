export default defineNuxtRouteMiddleware(async (to) => {
  // El cliente de Supabase termina de intercambiar el código OAuth al inicializarse.
  if (import.meta.server && to.path === '/dashboard' && (to.query.code || to.query.error)) return
  if (to.path === '/versiones') return
  const supabase = useSupabaseClient()
  const { data } = await supabase.auth.getSession()
  if (!data.session && to.path !== '/') return navigateTo('/')
  if (data.session && to.path === '/') return navigateTo('/dashboard')
})
