; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt -passes=simplifycfg,instcombine -simplifycfg-require-and-preserve-domtree=1 < %s -simplifycfg-merge-cond-stores=true -simplifycfg-merge-cond-stores-aggressively=false -phi-node-folding-threshold=2 -S | FileCheck %s

; This test should succeed and end up if-converted.
define void @test_simple(ptr %p, i32 %a, i32 %b) {
; CHECK-LABEL: @test_simple(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = or i32 [[A:%.*]], [[B:%.*]]
; CHECK-NEXT:    [[DOTNOT:%.*]] = icmp eq i32 [[TMP0]], 0
; CHECK-NEXT:    br i1 [[DOTNOT]], label [[TMP2:%.*]], label [[TMP1:%.*]]
; CHECK:       1:
; CHECK-NEXT:    [[X2:%.*]] = icmp ne i32 [[B]], 0
; CHECK-NEXT:    [[SPEC_SELECT:%.*]] = zext i1 [[X2]] to i32
; CHECK-NEXT:    store i32 [[SPEC_SELECT]], ptr [[P:%.*]], align 4
; CHECK-NEXT:    br label [[TMP2]]
; CHECK:       2:
; CHECK-NEXT:    ret void
;
entry:
  %x1 = icmp eq i32 %a, 0
  br i1 %x1, label %fallthrough, label %yes1

yes1:
  store i32 0, ptr %p
  br label %fallthrough

fallthrough:
  %x2 = icmp eq i32 %b, 0
  br i1 %x2, label %end, label %yes2

yes2:
  store i32 1, ptr %p
  br label %end

end:
  ret void
}

; This is the same as test_simple, but the branch target order has been swapped
define void @test_simple_commuted(ptr %p, i32 %a, i32 %b) {
; CHECK-LABEL: @test_simple_commuted(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[X1_NOT:%.*]] = icmp eq i32 [[A:%.*]], 0
; CHECK-NEXT:    [[X2:%.*]] = icmp eq i32 [[B:%.*]], 0
; CHECK-NEXT:    [[TMP0:%.*]] = or i1 [[X1_NOT]], [[X2]]
; CHECK-NEXT:    br i1 [[TMP0]], label [[TMP1:%.*]], label [[TMP2:%.*]]
; CHECK:       1:
; CHECK-NEXT:    [[SPEC_SELECT:%.*]] = zext i1 [[X2]] to i32
; CHECK-NEXT:    store i32 [[SPEC_SELECT]], ptr [[P:%.*]], align 4
; CHECK-NEXT:    br label [[TMP2]]
; CHECK:       2:
; CHECK-NEXT:    ret void
;
entry:
  %x1 = icmp eq i32 %a, 0
  br i1 %x1, label %yes1, label %fallthrough

yes1:
  store i32 0, ptr %p
  br label %fallthrough

fallthrough:
  %x2 = icmp eq i32 %b, 0
  br i1 %x2, label %yes2, label %end

yes2:
  store i32 1, ptr %p
  br label %end

end:
  ret void
}

; This test should entirely fold away, leaving one large basic block.
define void @test_recursive(ptr %p, i32 %a, i32 %b, i32 %c, i32 %d) {
; CHECK-LABEL: @test_recursive(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = or i32 [[A:%.*]], [[B:%.*]]
; CHECK-NEXT:    [[TMP1:%.*]] = or i32 [[TMP0]], [[C:%.*]]
; CHECK-NEXT:    [[TMP2:%.*]] = or i32 [[TMP1]], [[D:%.*]]
; CHECK-NEXT:    [[DOTNOT:%.*]] = icmp eq i32 [[TMP2]], 0
; CHECK-NEXT:    br i1 [[DOTNOT]], label [[TMP4:%.*]], label [[TMP3:%.*]]
; CHECK:       3:
; CHECK-NEXT:    [[X4_NOT:%.*]] = icmp eq i32 [[D]], 0
; CHECK-NEXT:    [[X3_NOT:%.*]] = icmp eq i32 [[C]], 0
; CHECK-NEXT:    [[X2:%.*]] = icmp ne i32 [[B]], 0
; CHECK-NEXT:    [[SPEC_SELECT:%.*]] = zext i1 [[X2]] to i32
; CHECK-NEXT:    [[SPEC_SELECT1:%.*]] = select i1 [[X3_NOT]], i32 [[SPEC_SELECT]], i32 2
; CHECK-NEXT:    [[SPEC_SELECT2:%.*]] = select i1 [[X4_NOT]], i32 [[SPEC_SELECT1]], i32 3
; CHECK-NEXT:    store i32 [[SPEC_SELECT2]], ptr [[P:%.*]], align 4
; CHECK-NEXT:    br label [[TMP4]]
; CHECK:       4:
; CHECK-NEXT:    ret void
;
entry:
  %x1 = icmp eq i32 %a, 0
  br i1 %x1, label %fallthrough, label %yes1

yes1:
  store i32 0, ptr %p
  br label %fallthrough

fallthrough:
  %x2 = icmp eq i32 %b, 0
  br i1 %x2, label %next, label %yes2

yes2:
  store i32 1, ptr %p
  br label %next

next:
  %x3 = icmp eq i32 %c, 0
  br i1 %x3, label %fallthrough2, label %yes3

yes3:
  store i32 2, ptr %p
  br label %fallthrough2

fallthrough2:
  %x4 = icmp eq i32 %d, 0
  br i1 %x4, label %end, label %yes4

yes4:
  store i32 3, ptr %p
  br label %end


end:
  ret void
}

; The code in each diamond is too large - it won't be if-converted so our
; heuristics should say no.
define void @test_not_ifconverted(ptr %p, i32 %a, i32 %b) {
; CHECK-LABEL: @test_not_ifconverted(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[X1:%.*]] = icmp eq i32 [[A:%.*]], 0
; CHECK-NEXT:    br i1 [[X1]], label [[FALLTHROUGH:%.*]], label [[YES1:%.*]]
; CHECK:       yes1:
; CHECK-NEXT:    [[Y1:%.*]] = or i32 [[B:%.*]], 55
; CHECK-NEXT:    [[Y2:%.*]] = add i32 [[Y1]], 24
; CHECK-NEXT:    [[Y3:%.*]] = and i32 [[Y2]], 67
; CHECK-NEXT:    store i32 [[Y3]], ptr [[P:%.*]], align 4
; CHECK-NEXT:    br label [[FALLTHROUGH]]
; CHECK:       fallthrough:
; CHECK-NEXT:    [[X2:%.*]] = icmp eq i32 [[B]], 0
; CHECK-NEXT:    br i1 [[X2]], label [[END:%.*]], label [[YES2:%.*]]
; CHECK:       yes2:
; CHECK-NEXT:    [[Z1:%.*]] = or i32 [[A]], 55
; CHECK-NEXT:    [[Z2:%.*]] = add i32 [[Z1]], 24
; CHECK-NEXT:    [[Z3:%.*]] = and i32 [[Z2]], 67
; CHECK-NEXT:    store i32 [[Z3]], ptr [[P]], align 4
; CHECK-NEXT:    br label [[END]]
; CHECK:       end:
; CHECK-NEXT:    ret void
;
entry:
  %x1 = icmp eq i32 %a, 0
  br i1 %x1, label %fallthrough, label %yes1

yes1:
  %y1 = or i32 %b, 55
  %y2 = add i32 %y1, 24
  %y3 = and i32 %y2, 67
  store i32 %y3, ptr %p
  br label %fallthrough

fallthrough:
  %x2 = icmp eq i32 %b, 0
  br i1 %x2, label %end, label %yes2

yes2:
  %z1 = or i32 %a, 55
  %z2 = add i32 %z1, 24
  %z3 = and i32 %z2, 67
  store i32 %z3, ptr %p
  br label %end

end:
  ret void
}

; The store to %p clobbers the previous store, so if-converting this would
; be illegal.
define void @test_aliasing1(ptr %p, i32 %a, i32 %b) {
; CHECK-LABEL: @test_aliasing1(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[X1:%.*]] = icmp eq i32 [[A:%.*]], 0
; CHECK-NEXT:    br i1 [[X1]], label [[FALLTHROUGH:%.*]], label [[YES1:%.*]]
; CHECK:       yes1:
; CHECK-NEXT:    store i32 0, ptr [[P:%.*]], align 4
; CHECK-NEXT:    br label [[FALLTHROUGH]]
; CHECK:       fallthrough:
; CHECK-NEXT:    [[Y1:%.*]] = load i32, ptr [[P]], align 4
; CHECK-NEXT:    [[X2:%.*]] = icmp eq i32 [[Y1]], 0
; CHECK-NEXT:    br i1 [[X2]], label [[END:%.*]], label [[YES2:%.*]]
; CHECK:       yes2:
; CHECK-NEXT:    store i32 1, ptr [[P]], align 4
; CHECK-NEXT:    br label [[END]]
; CHECK:       end:
; CHECK-NEXT:    ret void
;
entry:
  %x1 = icmp eq i32 %a, 0
  br i1 %x1, label %fallthrough, label %yes1

yes1:
  store i32 0, ptr %p
  br label %fallthrough

fallthrough:
  %y1 = load i32, ptr %p
  %x2 = icmp eq i32 %y1, 0
  br i1 %x2, label %end, label %yes2

yes2:
  store i32 1, ptr %p
  br label %end

end:
  ret void
}

; The load from %q aliases with %p, so if-converting this would be illegal.
define void @test_aliasing2(ptr %p, ptr %q, i32 %a, i32 %b) {
; CHECK-LABEL: @test_aliasing2(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[X1:%.*]] = icmp eq i32 [[A:%.*]], 0
; CHECK-NEXT:    br i1 [[X1]], label [[FALLTHROUGH:%.*]], label [[YES1:%.*]]
; CHECK:       yes1:
; CHECK-NEXT:    store i32 0, ptr [[P:%.*]], align 4
; CHECK-NEXT:    br label [[FALLTHROUGH]]
; CHECK:       fallthrough:
; CHECK-NEXT:    [[Y1:%.*]] = load i32, ptr [[Q:%.*]], align 4
; CHECK-NEXT:    [[X2:%.*]] = icmp eq i32 [[Y1]], 0
; CHECK-NEXT:    br i1 [[X2]], label [[END:%.*]], label [[YES2:%.*]]
; CHECK:       yes2:
; CHECK-NEXT:    store i32 1, ptr [[P]], align 4
; CHECK-NEXT:    br label [[END]]
; CHECK:       end:
; CHECK-NEXT:    ret void
;
entry:
  %x1 = icmp eq i32 %a, 0
  br i1 %x1, label %fallthrough, label %yes1

yes1:
  store i32 0, ptr %p
  br label %fallthrough

fallthrough:
  %y1 = load i32, ptr %q
  %x2 = icmp eq i32 %y1, 0
  br i1 %x2, label %end, label %yes2

yes2:
  store i32 1, ptr %p
  br label %end

end:
  ret void
}

declare void @f()

; This should get if-converted.
define i32 @test_diamond_simple(ptr %p, ptr %q, i32 %a, i32 %b) {
; CHECK-LABEL: @test_diamond_simple(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[X2:%.*]] = icmp ne i32 [[B:%.*]], 0
; CHECK-NEXT:    [[TMP0:%.*]] = or i32 [[A:%.*]], [[B]]
; CHECK-NEXT:    [[DOTNOT:%.*]] = icmp eq i32 [[TMP0]], 0
; CHECK-NEXT:    br i1 [[DOTNOT]], label [[TMP2:%.*]], label [[TMP1:%.*]]
; CHECK:       1:
; CHECK-NEXT:    [[SIMPLIFYCFG_MERGE:%.*]] = zext i1 [[X2]] to i32
; CHECK-NEXT:    store i32 [[SIMPLIFYCFG_MERGE]], ptr [[P:%.*]], align 4
; CHECK-NEXT:    br label [[TMP2]]
; CHECK:       2:
; CHECK-NEXT:    [[Z4:%.*]] = select i1 [[X2]], i32 3, i32 0
; CHECK-NEXT:    ret i32 [[Z4]]
;
entry:
  %x1 = icmp eq i32 %a, 0
  br i1 %x1, label %no1, label %yes1

yes1:
  store i32 0, ptr %p
  br label %fallthrough

no1:
  %z1 = add i32 %a, %b
  br label %fallthrough

fallthrough:
  %z2 = phi i32 [ %z1, %no1 ], [ 0, %yes1 ]
  %x2 = icmp eq i32 %b, 0
  br i1 %x2, label %no2, label %yes2

yes2:
  store i32 1, ptr %p
  br label %end

no2:
  %z3 = sub i32 %z2, %b
  br label %end

end:
  %z4 = phi i32 [ %z3, %no2 ], [ 3, %yes2 ]
  ret i32 %z4
}

; Now there is a call to f() in the bottom branch. The store in the first
; branch would now be reordered with respect to the call if we if-converted,
; so we must not.
define i32 @test_diamond_alias3(ptr %p, ptr %q, i32 %a, i32 %b) {
; CHECK-LABEL: @test_diamond_alias3(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[X1:%.*]] = icmp eq i32 [[A:%.*]], 0
; CHECK-NEXT:    br i1 [[X1]], label [[NO1:%.*]], label [[YES1:%.*]]
; CHECK:       yes1:
; CHECK-NEXT:    store i32 0, ptr [[P:%.*]], align 4
; CHECK-NEXT:    br label [[FALLTHROUGH:%.*]]
; CHECK:       no1:
; CHECK-NEXT:    call void @f()
; CHECK-NEXT:    [[Z1:%.*]] = add i32 [[A]], [[B:%.*]]
; CHECK-NEXT:    br label [[FALLTHROUGH]]
; CHECK:       fallthrough:
; CHECK-NEXT:    [[Z2:%.*]] = phi i32 [ [[Z1]], [[NO1]] ], [ 0, [[YES1]] ]
; CHECK-NEXT:    [[X2:%.*]] = icmp eq i32 [[B]], 0
; CHECK-NEXT:    br i1 [[X2]], label [[NO2:%.*]], label [[YES2:%.*]]
; CHECK:       yes2:
; CHECK-NEXT:    store i32 1, ptr [[P]], align 4
; CHECK-NEXT:    br label [[END:%.*]]
; CHECK:       no2:
; CHECK-NEXT:    call void @f()
; CHECK-NEXT:    [[Z3:%.*]] = sub i32 [[Z2]], [[B]]
; CHECK-NEXT:    br label [[END]]
; CHECK:       end:
; CHECK-NEXT:    [[Z4:%.*]] = phi i32 [ [[Z3]], [[NO2]] ], [ 3, [[YES2]] ]
; CHECK-NEXT:    ret i32 [[Z4]]
;
entry:
  %x1 = icmp eq i32 %a, 0
  br i1 %x1, label %no1, label %yes1

yes1:
  store i32 0, ptr %p
  br label %fallthrough

no1:
  call void @f()
  %z1 = add i32 %a, %b
  br label %fallthrough

fallthrough:
  %z2 = phi i32 [ %z1, %no1 ], [ 0, %yes1 ]
  %x2 = icmp eq i32 %b, 0
  br i1 %x2, label %no2, label %yes2

yes2:
  store i32 1, ptr %p
  br label %end

no2:
  call void @f()
  %z3 = sub i32 %z2, %b
  br label %end

end:
  %z4 = phi i32 [ %z3, %no2 ], [ 3, %yes2 ]
  ret i32 %z4
}

; This test has an outer if over the two triangles. This requires creating a new BB to hold the store.
define void @test_outer_if(ptr %p, i32 %a, i32 %b, i32 %c) {
; CHECK-LABEL: @test_outer_if(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[X3:%.*]] = icmp eq i32 [[C:%.*]], 0
; CHECK-NEXT:    br i1 [[X3]], label [[END:%.*]], label [[CONTINUE:%.*]]
; CHECK:       continue:
; CHECK-NEXT:    [[TMP0:%.*]] = or i32 [[A:%.*]], [[B:%.*]]
; CHECK-NEXT:    [[DOTNOT:%.*]] = icmp eq i32 [[TMP0]], 0
; CHECK-NEXT:    br i1 [[DOTNOT]], label [[END]], label [[TMP1:%.*]]
; CHECK:       1:
; CHECK-NEXT:    [[X2:%.*]] = icmp ne i32 [[B]], 0
; CHECK-NEXT:    [[SPEC_SELECT:%.*]] = zext i1 [[X2]] to i32
; CHECK-NEXT:    store i32 [[SPEC_SELECT]], ptr [[P:%.*]], align 4
; CHECK-NEXT:    br label [[END]]
; CHECK:       end:
; CHECK-NEXT:    ret void
;
entry:
  %x3 = icmp eq i32 %c, 0
  br i1 %x3, label %end, label %continue
continue:
  %x1 = icmp eq i32 %a, 0
  br i1 %x1, label %fallthrough, label %yes1
yes1:
  store i32 0, ptr %p
  br label %fallthrough
  fallthrough:
  %x2 = icmp eq i32 %b, 0
  br i1 %x2, label %end, label %yes2
yes2:
  store i32 1, ptr %p
  br label %end
end:
  ret void
}