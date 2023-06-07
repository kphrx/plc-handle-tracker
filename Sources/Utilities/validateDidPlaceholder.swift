func validateDidPlaceholder(_ did: String) -> Bool {
  if !did.hasPrefix("did:plc:") {
    return false
  }
  let specificId = did.replacingOccurrences(of: "did:plc:", with: "")
  return
    if specificId.rangeOfCharacter(
      from: .init(charactersIn: "abcdefghijklmnopqrstuvwxyz234567").inverted) != nil
  {
    false
  } else {
    specificId.count >= 24
  }
}
