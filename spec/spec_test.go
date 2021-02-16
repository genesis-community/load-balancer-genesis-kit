package spec_test

import (
	"path/filepath"
	"runtime"

	. "github.com/genesis-community/testkit/testing"
	. "github.com/onsi/ginkgo"
)

var _ = Describe("loadbalancer Kit", func() {
	BeforeSuite(func() {
		_, filename, _, _ := runtime.Caller(0)
		KitDir, _ = filepath.Abs(filepath.Join(filepath.Dir(filename), "../"))
	})

	Describe("loadbalancer", func() {
		Test(Environment{
			Name:        "base",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "cf",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "static-ips",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "vip",
			CloudConfig: "aws",
			CPI:         "aws",
		})
	})
})
