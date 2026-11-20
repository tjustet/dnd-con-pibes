import test from 'node:test'
import assert from 'node:assert/strict'
import { actualizarCampana, anotarTirada, cobreDe, estadoInicial } from '../app/utils/partida.js'
import { listaGuardada, notasDeFicha } from '../app/utils/ficha.js'

// Simula la condición de igualdad de PostgREST, incluyendo dos lectores del mismo estado.
function campanas(fila) {
  return { from() {
    let campo, cambio, esperado
    const q = {
      select(c) { if (!cambio) campo = c; return q },
      eq(k,v) { if (k !== 'id') esperado = JSON.parse(v); return q },
      is(k,v) { esperado=v; return q },
      update(v) { cambio=v; return q },
      async single() { return { data: { [campo]: structuredClone(fila[campo]) } } },
      async maybeSingle() {
        const [k] = Object.keys(cambio)
        if (JSON.stringify(fila[k]) !== JSON.stringify(esperado)) return { data:null }
        Object.assign(fila, cambio)
        return {data:{id:'mesa'}}
      }
    }
    return q
  }}
}
test('dos tiradas simultáneas y un reintento conservan un único registro por dado', async () => {
  const fila = { historial_dados: null }, db=campanas(fila)
  await Promise.all(['a','b'].map(id => anotarTirada(db,'mesa',{id})))
  await anotarTirada(db,'mesa',{id:'a'})
  assert.deepEqual(fila.historial_dados.map(t=>t.id),['a','b'])
})
test('una venta y una proyección concurrentes conservan ambos campos', async () => {
  const fila = { mesa_estado: null }, db=campanas(fila)
  await Promise.all(['carritos','tiendaVisible'].map(k =>
    actualizarCampana(db,'mesa','mesa_estado',m=>({...m,[k]:{id:1}}))))
  assert.deepEqual(Object.keys(fila.mesa_estado).sort(),['carritos','tiendaVisible'])
})
test('un estado parcial mantiene campos de otras sesiones', () => {
  assert.deepEqual(estadoInicial({ entidadVisible:'dragón' }),{ pjs:[],npcs:[],enemigos:[],carritos:{},entidadVisible:'dragón' })
})
test('las notas antiguas, los JSON y las monedas de ambos formatos se pueden leer', () => {
  assert.deepEqual(notasDeFicha('Taberna cerrada'),[{titulo:'Notas',texto:'Taberna cerrada'}])
  assert.deepEqual(listaGuardada('[{"nombre":"Daga"}]'),[{nombre:'Daga'}])
  assert.equal(cobreDe({monedas:{po:1,pc:2}}),1002)
  assert.equal(cobreDe({monedas_oro:2,monedas_cobre:3,monedas:{po:1}}),2003)
})
