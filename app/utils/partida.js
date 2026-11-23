// Mantiene las equivalencias en cobre usadas por la economía de esta campaña.
export function cobreDe(pj) {
  const columnas = (Number(pj.monedas_platino) || 0) * 10000 + (Number(pj.monedas_oro) || 0) * 1000
    + (Number(pj.monedas_plata) || 0) * 100 + (Number(pj.monedas_cobre) || 0)
  const m = pj.monedas || {}
  return columnas || (Number(m.ppt) || 0) * 10000 + (Number(m.po) || 0) * 1000
    + (Number(m.plata) || 0) * 100 + (Number(m.pc) || 0)
}

export function estadoInicial(estado = {}) {
  const mesa = { ...estado }
  for (const campo of ['pjs', 'npcs', 'enemigos']) {
    if (!Array.isArray(mesa[campo])) mesa[campo] = []
  }
  mesa.carritos ||= {}
  mesa.entidadVisible ??= null
  return mesa
}

// La condición sobre el JSON original evita pisar la edición concurrente de otro cliente.
async function actualizarJson(db, tabla, id, campo, transformar) {
  for (let intento = 0; intento < 5; intento++) {
    const { data, error } = await db.from(tabla).select(campo).eq('id', id).single()
    if (error) throw error
    const anterior = data[campo]
    const siguiente = transformar(structuredClone(anterior))
    let q = db.from(tabla).update({ [campo]: siguiente }).eq('id', id)
    q = anterior == null ? q.is(campo, null) : q.eq(campo, JSON.stringify(anterior))
    const respuesta = await q.select('id').maybeSingle()
    if (respuesta.error) throw respuesta.error
    if (respuesta.data) return siguiente
  }
  throw new Error('La mesa cambió durante el guardado. Reintentá la acción.')
}

export const actualizarCampana = (db, id, campo, transformar) => actualizarJson(db, 'campaigns', id, campo, transformar)

export function asignarEmpleado(db, tienda, id, contratar) {
  return actualizarJson(db, 'tiendas_sesion', tienda, 'empleados', previo => {
    const ids = (Array.isArray(previo) ? previo : []).map(e => e?.id ?? e).filter(Boolean)
    return contratar ? [...new Set([...ids, id])] : ids.filter(actual => actual !== id)
  })
}

export function anotarTirada(db, id, tirada) {
  return actualizarCampana(db, id, 'historial_dados', previo =>
    [tirada, ...(Array.isArray(previo) ? previo : []).filter(t => t.id !== tirada.id)].slice(0, 30))
}

export function idOperacion() {
  if (typeof crypto.randomUUID === 'function') return crypto.randomUUID()
  const bytes = crypto.getRandomValues(new Uint8Array(16))
  bytes[6] = (bytes[6] & 15) | 64
  bytes[8] = (bytes[8] & 63) | 128
  const hex = Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('')
  return [hex.slice(0,8), hex.slice(8,12), hex.slice(12,16), hex.slice(16,20), hex.slice(20)].join('-')
}
