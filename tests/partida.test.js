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
test('una tirada devuelve el historial confirmado y comunica el fallo al cliente', async () => {
  const registro = { id: 'a', total: 12 }
  const db = { rpc: async (nombre, args) => {
    assert.equal(nombre, 'dnd_registrar_tirada')
    assert.deepEqual(args, { p_campana: 'mesa', p_tirada: registro })
    return { data: [registro] }
  } }
  assert.deepEqual(await anotarTirada(db, 'mesa', registro), [registro])
  await assert.rejects(anotarTirada({ rpc: async () => ({ error: new Error('Falló el guardado') }) }, 'mesa', registro))
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
