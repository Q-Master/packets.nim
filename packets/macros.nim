import std/macros
import internal/packet


macro packet*(head, body: untyped): untyped =
  let (packetname, basenames) = getNameAndBases(head)
  result = newStmtList()
  let (typeNode, requiredFields, exportedFields, allFields, baseFunctions) = createType(packetname, basenames, body)
  typeNode.setLineInfo(head.lineInfoObj)
  result.add(typeNode)
  result.add(baseFunctions)
  let deserData = createDeserData($packetname, exportedFields, allFields, requiredFields)
  result.add(deserData)
  let serData = createSerData($packetname, exportedFields, allFields, requiredFields)
  result.add(serData)
  echo result.repr


macro arrayPacket*(head, body: untyped): untyped =
  let (packetname, basenames) = getNameAndBases(head)
  result = newStmtList()
  let (typeNode, requiredFields, exportedFields, allFields, baseFunctions) = createType(packetname, basenames, body, true)
  typeNode.setLineInfo(head.lineInfoObj)
  result.add(typeNode)
  result.add(baseFunctions)
  let deserData = createArrayDeserData($packetname, exportedFields, allFields, requiredFields.len())
  result.add(deserData)
  let serData = createArraySerData($packetname, exportedFields, allFields)
  result.add(serData)
