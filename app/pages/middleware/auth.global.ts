export default defineNuxtRouteMiddleware((to, from) => {
  const user = useSupabaseUser()

  // Si no hay usuario y quiere ir a cualquier lado que no sea el login ('/')
  if (!user.value && to.path !== '/') {
    return navigateTo('/') // Lo pateamos a la pantalla de inicio
  }

  // Si YA hay usuario y quiere volver a ver el login ('/')
  if (user.value && to.path === '/') {
    return navigateTo('/dashboard') // Lo mandamos directo adentro
  }
})