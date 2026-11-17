#[inline(never)]
pub fn sum(lhs: i32, rhs: i32) -> i32 {
    lhs + rhs
}

#[cfg(test)]
mod tests {
    use super::sum;
    use std::hint::black_box;

    #[test]
    fn strong() {
        assert_eq!(sum(black_box(-2), black_box(2)), 0);
    }

    #[test]
    fn weak() {
        assert_eq!(sum(black_box(2), black_box(0)), 2);
    }
}
