export function listaGuardada(valor) {
  if (Array.isArray(valor)) return valor
  if (typeof valor === 'string') {
    try {
      const lista = JSON.parse(valor)
      if (Array.isArray(lista)) return lista
    } catch { /* Las fichas antiguas también admitían texto libre. */ }
  }
  return []
}

export function notasDeFicha(valor) {
  if (typeof valor === 'string' && valor.trim() && !valor.trimStart().startsWith('[')) {
    return [{ titulo: 'Notas', texto: valor }]
  }
  return listaGuardada(valor)
}
