import { shallowRef, ref, onBeforeUnmount } from 'vue'
import { idOperacion } from '../utils/partida.js'

// La animación revela una tirada ya resuelta. El registro recibe esos mismos valores.
export function useTiradaAnimada() {
  const tirada = shallowRef(null)
  const tirando = ref(false)
  let finalizar
  let plazo

  function lanzar(caras, bono, titulo, efecto = null) {
    if (tirando.value || !caras.length) return
    const dados = caras.map(c => ({ caras: c, valor: 1 + Math.floor(Math.random() * c) }))
    const modificador = Number(bono) || 0
    const duracion = window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : 980
    const actual = {
      id: idOperacion(), titulo, efecto, dados, bono: modificador,
      total: dados.reduce((suma, d) => suma + d.valor, modificador),
      inicio: performance.now(), duracion
    }
    tirada.value = actual
    if (!duracion) return Promise.resolve(actual)
    tirando.value = true
    return new Promise(resolve => {
      finalizar = () => {
        clearTimeout(plazo)
        finalizar = null
        tirando.value = false
        resolve(actual)
      }
      plazo = setTimeout(finalizar, duracion)
    })
  }
  // Al salir antes del aterrizaje también se registra la tirada iniciada.
  onBeforeUnmount(() => finalizar?.())
  return { tirada, tirando, lanzar }
}
