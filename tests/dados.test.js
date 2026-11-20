import test from 'node:test'
import assert from 'node:assert/strict'
import { createRenderer } from 'vue'
import { modificadorCaracteristica } from '../app/utils/ficha.js'
import { useTiradaAnimada } from '../app/composables/useTiradaAnimada.js'

function montar(reducir, t) {
  const anterior = Object.getOwnPropertyDescriptor(globalThis, 'window')
  Object.defineProperty(globalThis, 'window', { configurable: true, value: { matchMedia: () => ({ matches: reducir }) } })
  t.after(() => {
    if (anterior) Object.defineProperty(globalThis,'window',anterior)
    else delete globalThis.window
  })
  const renderer = createRenderer({ createComment: () => ({}), insert() {}, remove() {}, parentNode() {}, nextSibling() {} })
  let motor
  const app = renderer.createApp({ setup() { motor = useTiradaAnimada(); return () => null } })
  app.mount({})
  return { motor, app }
}

test('la tirada conserva las caras, el bono y el efecto aunque cambie la selección', async t => {
  const { motor, app } = montar(false, t)
  t.mock.method(Math,'random',() => .999999)
  const caras = [20,100]
  const efecto = { nombre: 'Fuego' }
  const tirada = motor.lanzar(caras,-3,'Ataque',efecto)
  caras.length = 0
  assert.equal(motor.tirando.value,true)
  assert.equal(motor.lanzar([6],0,'Otra'),undefined)
  app.unmount()
  const resultado = await tirada
  assert.deepEqual(resultado.dados,[{caras:20,valor:20},{caras:100,valor:100}])
  assert.equal(resultado.total,117)
  assert.equal(resultado.efecto,efecto)
  assert.equal(motor.tirando.value,false)
})

test('con movimiento reducido el resultado es inmediato y repetir genera una tirada nueva', async t => {
  const { motor, app } = montar(true, t)
  t.mock.method(Math,'random',() => 0)
  assert.equal(motor.lanzar([],0,'Vacía'),undefined)
  const primera = await motor.lanzar([4,20,100],-5,'Manual')
  const segunda = await motor.lanzar([4,20,100],-5,'Manual')
  assert.equal(primera.duracion,0)
  assert.equal(motor.tirando.value,false)
  assert.notEqual(segunda.id,primera.id)
  assert.equal(segunda.total,-2)
  app.unmount()
})

test('una ficha incompleta usa un bono neutro y conserva los modificadores válidos', () => {
  for (const valor of [undefined, null, '', 'desconocido']) assert.equal(modificadorCaracteristica(valor), 0)
  assert.equal(modificadorCaracteristica('9'), -1)
  assert.equal(modificadorCaracteristica(18), 4)
})
