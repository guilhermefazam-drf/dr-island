extension Int {
    /// nil for 0, so a card header shows no count while its list is loading or empty.
    var nonZero: Int? { self == 0 ? nil : self }
}
